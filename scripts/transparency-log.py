#!/usr/bin/env python3

"""
Transparency Log System
Public transparency log (Sigstore/Rekor-style) for update metadata
Requirement 9.5: Releases recorded in transparency log
"""

import os
import json
import sys
import hashlib
import time
from pathlib import Path
from datetime import datetime
import requests
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ed25519
from cryptography.hazmat.primitives.serialization import load_pem_private_key

class TransparencyLog:
    def __init__(self, log_dir="/var/lib/tuf/transparency-log"):
        self.log_dir = Path(log_dir)
        self.log_dir.mkdir(parents=True, exist_ok=True)
        
        # Log files
        self.entries_file = self.log_dir / "entries.jsonl"
        self.merkle_tree_file = self.log_dir / "merkle-tree.json"
        self.log_config_file = self.log_dir / "config.json"
        
        # Initialize log
        self.load_config()
        self.log_entries = self.load_entries()
        
    def load_config(self):
        """Load transparency log configuration"""
        if self.log_config_file.exists():
            with open(self.log_config_file, 'r') as f:
                self.config = json.load(f)
        else:
            self.config = {
                "log_id": self.generate_log_id(),
                "created_at": datetime.utcnow().isoformat() + "Z",
                "description": "Hardened OS Update Transparency Log",
                "public_key": None,
                "tree_size": 0
            }
            self.save_config()
    
    def save_config(self):
        """Save transparency log configuration"""
        with open(self.log_config_file, 'w') as f:
            json.dump(self.config, f, indent=2)
    
    def generate_log_id(self):
        """Generate unique log ID"""
        timestamp = str(int(time.time()))
        hostname = os.uname().nodename
        combined = f"{hostname}:{timestamp}"
        return hashlib.sha256(combined.encode()).hexdigest()[:32]
    
    def load_entries(self):
        """Load existing log entries"""
        entries = []
        if self.entries_file.exists():
            with open(self.entries_file, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line:
                        entries.append(json.loads(line))
        return entries
    
    def calculate_leaf_hash(self, entry_data):
        """Calculate leaf hash for Merkle tree"""
        # Create canonical JSON representation
        canonical_json = json.dumps(entry_data, separators=(',', ':'), sort_keys=True)
        
        # Hash with prefix for leaf nodes (RFC 6962 style)
        leaf_prefix = b'\x00'  # 0x00 for leaf nodes
        return hashlib.sha256(leaf_prefix + canonical_json.encode('utf-8')).digest()
    
    def calculate_internal_hash(self, left_hash, right_hash):
        """Calculate internal node hash for Merkle tree"""
        # Hash with prefix for internal nodes (RFC 6962 style)
        internal_prefix = b'\x01'  # 0x01 for internal nodes
        return hashlib.sha256(internal_prefix + left_hash + right_hash).digest()
    
    def build_merkle_tree(self, leaf_hashes):
        """Build Merkle tree from leaf hashes"""
        if not leaf_hashes:
            return None, []
        
        if len(leaf_hashes) == 1:
            return leaf_hashes[0], [leaf_hashes[0]]
        
        # Build tree bottom-up
        current_level = leaf_hashes[:]
        tree_levels = [current_level[:]]
        
        while len(current_level) > 1:
            next_level = []
            
            # Process pairs
            for i in range(0, len(current_level), 2):
                left = current_level[i]
                
                if i + 1 < len(current_level):
                    right = current_level[i + 1]
                else:
                    # Odd number of nodes, duplicate the last one
                    right = left
                
                parent_hash = self.calculate_internal_hash(left, right)
                next_level.append(parent_hash)
            
            tree_levels.append(next_level[:])
            current_level = next_level
        
        root_hash = current_level[0]
        return root_hash, tree_levels
    
    def create_inclusion_proof(self, entry_index, tree_levels):
        """Create inclusion proof for an entry"""
        if entry_index >= len(tree_levels[0]):
            raise ValueError("Entry index out of range")
        
        proof = []
        current_index = entry_index
        
        # Traverse up the tree
        for level in tree_levels[:-1]:  # Exclude root level
            # Find sibling
            if current_index % 2 == 0:
                # Left child, sibling is to the right
                sibling_index = current_index + 1
            else:
                # Right child, sibling is to the left
                sibling_index = current_index - 1
            
            if sibling_index < len(level):
                sibling_hash = level[sibling_index]
                proof.append({
                    "hash": sibling_hash.hex(),
                    "is_right": current_index % 2 == 0
                })
            
            current_index = current_index // 2
        
        return proof
    
    def verify_inclusion_proof(self, entry_data, entry_index, proof, root_hash):
        """Verify inclusion proof for an entry"""
        # Calculate leaf hash
        leaf_hash = self.calculate_leaf_hash(entry_data)
        current_hash = leaf_hash
        
        # Apply proof steps
        for step in proof:
            sibling_hash = bytes.fromhex(step["hash"])
            
            if step["is_right"]:
                # Sibling is right child
                current_hash = self.calculate_internal_hash(current_hash, sibling_hash)
            else:
                # Sibling is left child
                current_hash = self.calculate_internal_hash(sibling_hash, current_hash)
        
        return current_hash == root_hash
    
    def add_entry(self, entry_type, entry_data):
        """Add entry to transparency log"""
        # Create log entry
        entry = {
            "log_index": len(self.log_entries),
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "entry_type": entry_type,
            "data": entry_data,
            "log_id": self.config["log_id"]
        }
        
        # Add to entries list
        self.log_entries.append(entry)
        
        # Append to entries file
        with open(self.entries_file, 'a') as f:
            f.write(json.dumps(entry) + '\n')
        
        # Rebuild Merkle tree
        leaf_hashes = [self.calculate_leaf_hash(e) for e in self.log_entries]
        root_hash, tree_levels = self.build_merkle_tree(leaf_hashes)
        
        # Update tree size
        self.config["tree_size"] = len(self.log_entries)
        self.save_config()
        
        # Save Merkle tree
        merkle_data = {
            "tree_size": len(self.log_entries),
            "root_hash": root_hash.hex() if root_hash else None,
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }
        
        with open(self.merkle_tree_file, 'w') as f:
            json.dump(merkle_data, f, indent=2)
        
        print(f"Added entry {entry['log_index']} to transparency log")
        return entry
    
    def get_entry(self, log_index):
        """Get entry by log index"""
        if log_index < 0 or log_index >= len(self.log_entries):
            raise ValueError("Log index out of range")
        
        return self.log_entries[log_index]
    
    def get_entries(self, start_index=0, count=None):
        """Get multiple entries"""
        if count is None:
            return self.log_entries[start_index:]
        else:
            return self.log_entries[start_index:start_index + count]
    
    def get_inclusion_proof(self, log_index):
        """Get inclusion proof for an entry"""
        if log_index < 0 or log_index >= len(self.log_entries):
            raise ValueError("Log index out of range")
        
        # Rebuild Merkle tree
        leaf_hashes = [self.calculate_leaf_hash(e) for e in self.log_entries]
        root_hash, tree_levels = self.build_merkle_tree(leaf_hashes)
        
        # Create inclusion proof
        proof = self.create_inclusion_proof(log_index, tree_levels)
        
        return {
            "log_index": log_index,
            "tree_size": len(self.log_entries),
            "root_hash": root_hash.hex(),
            "proof": proof
        }
    
    def verify_entry(self, log_index):
        """Verify an entry's inclusion in the log"""
        entry = self.get_entry(log_index)
        proof_data = self.get_inclusion_proof(log_index)
        
        root_hash = bytes.fromhex(proof_data["root_hash"])
        proof = proof_data["proof"]
        
        is_valid = self.verify_inclusion_proof(entry, log_index, proof, root_hash)
        
        return {
            "log_index": log_index,
            "entry": entry,
            "proof": proof_data,
            "verified": is_valid
        }
    
    def log_update_release(self, update_metadata):
        """Log an update release to transparency log"""
        entry_data = {
            "update_id": update_metadata.get("update_id"),
            "version": update_metadata.get("version"),
            "targets": update_metadata.get("targets", {}),
            "signatures": update_metadata.get("signatures", []),
            "metadata_hash": self.calculate_metadata_hash(update_metadata)
        }
        
        return self.add_entry("update_release", entry_data)
    
    def log_rollout_event(self, rollout_data):
        """Log a rollout event to transparency log"""
        entry_data = {
            "update_id": rollout_data.get("update_id"),
            "event_type": rollout_data.get("event_type"),  # start, stage_change, rollback, complete
            "stage": rollout_data.get("stage"),
            "percentage": rollout_data.get("percentage"),
            "health_status": rollout_data.get("health_status")
        }
        
        return self.add_entry("rollout_event", entry_data)
    
    def log_security_event(self, security_data):
        """Log a security event to transparency log"""
        entry_data = {
            "event_type": security_data.get("event_type"),
            "severity": security_data.get("severity"),
            "description": security_data.get("description"),
            "affected_systems": security_data.get("affected_systems", []),
            "mitigation": security_data.get("mitigation")
        }
        
        return self.add_entry("security_event", entry_data)
    
    def calculate_metadata_hash(self, metadata):
        """Calculate hash of metadata for transparency log"""
        canonical_json = json.dumps(metadata, separators=(',', ':'), sort_keys=True)
        return hashlib.sha256(canonical_json.encode('utf-8')).hexdigest()
    
    def get_log_info(self):
        """Get transparency log information"""
        # Calculate current root hash
        if self.log_entries:
            leaf_hashes = [self.calculate_leaf_hash(e) for e in self.log_entries]
            root_hash, _ = self.build_merkle_tree(leaf_hashes)
            current_root = root_hash.hex() if root_hash else None
        else:
            current_root = None
        
        return {
            "log_id": self.config["log_id"],
            "description": self.config["description"],
            "created_at": self.config["created_at"],
            "tree_size": len(self.log_entries),
            "root_hash": current_root,
            "last_update": datetime.utcnow().isoformat() + "Z"
        }
    
    def search_entries(self, entry_type=None, update_id=None, limit=100):
        """Search log entries"""
        results = []
        
        for entry in self.log_entries:
            # Filter by entry type
            if entry_type and entry["entry_type"] != entry_type:
                continue
            
            # Filter by update ID
            if update_id and entry["data"].get("update_id") != update_id:
                continue
            
            results.append(entry)
            
            if len(results) >= limit:
                break
        
        return results

def main():
    """Main function for command line usage"""
    if len(sys.argv) < 2:
        print("Usage: transparency-log.py <command> [args...]")
        print("Commands:")
        print("  info                           - Get log information")
        print("  add-update <metadata_file>     - Log update release")
        print("  add-rollout <event_data>       - Log rollout event")
        print("  get <index>                    - Get entry by index")
        print("  verify <index>                 - Verify entry inclusion")
        print("  search [type] [update_id]      - Search entries")
        print("  list [start] [count]           - List entries")
        sys.exit(1)
    
    try:
        log = TransparencyLog()
        command = sys.argv[1]
        
        if command == "info":
            info = log.get_log_info()
            print("Transparency Log Information:")
            for key, value in info.items():
                print(f"  {key}: {value}")
                
        elif command == "add-update":
            if len(sys.argv) < 3:
                print("Error: add-update requires metadata file")
                sys.exit(1)
            
            metadata_file = sys.argv[2]
            with open(metadata_file, 'r') as f:
                metadata = json.load(f)
            
            entry = log.log_update_release(metadata)
            print(f"Logged update release: index {entry['log_index']}")
            
        elif command == "add-rollout":
            if len(sys.argv) < 3:
                print("Error: add-rollout requires event data (JSON)")
                sys.exit(1)
            
            event_data = json.loads(sys.argv[2])
            entry = log.log_rollout_event(event_data)
            print(f"Logged rollout event: index {entry['log_index']}")
            
        elif command == "get":
            if len(sys.argv) < 3:
                print("Error: get requires log index")
                sys.exit(1)
            
            log_index = int(sys.argv[2])
            entry = log.get_entry(log_index)
            print(json.dumps(entry, indent=2))
            
        elif command == "verify":
            if len(sys.argv) < 3:
                print("Error: verify requires log index")
                sys.exit(1)
            
            log_index = int(sys.argv[2])
            result = log.verify_entry(log_index)
            
            print(f"Entry {log_index} verification:")
            print(f"  Verified: {result['verified']}")
            print(f"  Tree size: {result['proof']['tree_size']}")
            print(f"  Root hash: {result['proof']['root_hash']}")
            
        elif command == "search":
            entry_type = sys.argv[2] if len(sys.argv) > 2 else None
            update_id = sys.argv[3] if len(sys.argv) > 3 else None
            
            results = log.search_entries(entry_type, update_id)
            print(f"Found {len(results)} entries:")
            
            for entry in results:
                print(f"  {entry['log_index']}: {entry['entry_type']} at {entry['timestamp']}")
                
        elif command == "list":
            start_index = int(sys.argv[2]) if len(sys.argv) > 2 else 0
            count = int(sys.argv[3]) if len(sys.argv) > 3 else 10
            
            entries = log.get_entries(start_index, count)
            print(f"Entries {start_index} to {start_index + len(entries) - 1}:")
            
            for entry in entries:
                print(f"  {entry['log_index']}: {entry['entry_type']} at {entry['timestamp']}")
                
        else:
            print(f"Unknown command: {command}")
            sys.exit(1)
            
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()