#!/usr/bin/env python3

"""
TUF Client Update System
Client-side update verification and application logic
Requirement 8.2: Mandatory signature verification before installation
"""

import os
import json
import sys
import hashlib
import requests
import tempfile
from pathlib import Path
from datetime import datetime
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ed25519
from cryptography.hazmat.primitives.serialization import load_pem_public_key

class TUFClient:
    def __init__(self, server_url="http://localhost:8080", cache_dir="/var/cache/tuf"):
        self.server_url = server_url.rstrip('/')
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        
        # TUF metadata cache
        self.metadata_cache = self.cache_dir / "metadata"
        self.metadata_cache.mkdir(exist_ok=True)
        
        # Root keys (loaded from initial root.json)
        self.root_keys = {}
        self.trusted_root = None
        
    def download_metadata(self, metadata_name):
        """Download metadata from update server"""
        url = f"{self.server_url}/metadata/{metadata_name}"
        
        try:
            response = requests.get(url, timeout=30)
            response.raise_for_status()
            return response.json()
        except requests.RequestException as e:
            raise Exception(f"Failed to download {metadata_name}: {e}")
    
    def verify_signature(self, signed_metadata, role_keys):
        """Verify metadata signature"""
        if "signed" not in signed_metadata or "signatures" not in signed_metadata:
            raise ValueError("Invalid signed metadata format")
        
        metadata = signed_metadata["signed"]
        signatures = signed_metadata["signatures"]
        
        # Create canonical JSON for verification
        canonical_bytes = json.dumps(metadata, separators=(',', ':'), sort_keys=True).encode('utf-8')
        
        # Verify at least one signature
        verified_signatures = 0
        for signature in signatures:
            key_id = signature["keyid"]
            sig_bytes = bytes.fromhex(signature["signature"])
            
            if key_id in role_keys:
                try:
                    public_key = role_keys[key_id]
                    public_key.verify(sig_bytes, canonical_bytes)
                    verified_signatures += 1
                except Exception as e:
                    print(f"Signature verification failed for key {key_id}: {e}")
        
        return verified_signatures > 0
    
    def load_root_keys(self, root_metadata):
        """Load public keys from root metadata"""
        keys = {}
        
        for key_id, key_info in root_metadata["signed"]["keys"].items():
            if key_info["keytype"] == "ed25519":
                public_key_pem = key_info["keyval"]["public"].encode('utf-8')
                public_key = load_pem_public_key(public_key_pem)
                keys[key_id] = public_key
        
        return keys
    
    def initialize_root_trust(self, root_file=None):
        """Initialize root trust (first time setup)"""
        if root_file:
            # Load from local file (initial trust establishment)
            with open(root_file, 'r') as f:
                root_metadata = json.load(f)
        else:
            # Download from server (subsequent updates)
            root_metadata = self.download_metadata("root.json")
        
        # Load root keys
        self.root_keys = self.load_root_keys(root_metadata)
        self.trusted_root = root_metadata
        
        # Cache root metadata
        root_cache_file = self.metadata_cache / "root.json"
        with open(root_cache_file, 'w') as f:
            json.dump(root_metadata, f, indent=2)
        
        print(f"Initialized root trust with {len(self.root_keys)} keys")
    
    def update_metadata(self):
        """Update all TUF metadata"""
        if not self.trusted_root:
            raise Exception("Root trust not initialized")
        
        print("Updating TUF metadata...")
        
        # 1. Update timestamp metadata
        timestamp_metadata = self.download_metadata("timestamp.json")
        
        # Get timestamp keys from root
        timestamp_role = self.trusted_root["signed"]["roles"]["timestamp"]
        timestamp_keys = {kid: self.root_keys[kid] for kid in timestamp_role["keyids"]}
        
        if not self.verify_signature(timestamp_metadata, timestamp_keys):
            raise Exception("Timestamp metadata signature verification failed")
        
        # 2. Update snapshot metadata
        snapshot_metadata = self.download_metadata("snapshot.json")
        
        # Get snapshot keys from root
        snapshot_role = self.trusted_root["signed"]["roles"]["snapshot"]
        snapshot_keys = {kid: self.root_keys[kid] for kid in snapshot_role["keyids"]}
        
        if not self.verify_signature(snapshot_metadata, snapshot_keys):
            raise Exception("Snapshot metadata signature verification failed")
        
        # 3. Update targets metadata
        targets_metadata = self.download_metadata("targets.json")
        
        # Get targets keys from root
        targets_role = self.trusted_root["signed"]["roles"]["targets"]
        targets_keys = {kid: self.root_keys[kid] for kid in targets_role["keyids"]}
        
        if not self.verify_signature(targets_metadata, targets_keys):
            raise Exception("Targets metadata signature verification failed")
        
        # Cache all metadata
        for name, metadata in [
            ("timestamp.json", timestamp_metadata),
            ("snapshot.json", snapshot_metadata),
            ("targets.json", targets_metadata)
        ]:
            cache_file = self.metadata_cache / name
            with open(cache_file, 'w') as f:
                json.dump(metadata, f, indent=2)
        
        print("Metadata updated and verified successfully")
        return targets_metadata
    
    def download_target(self, target_name, target_info):
        """Download and verify a target file"""
        url = f"{self.server_url}/targets/{target_name}"
        
        print(f"Downloading target: {target_name}")
        
        # Download target file
        try:
            response = requests.get(url, stream=True, timeout=60)
            response.raise_for_status()
            
            # Create temporary file
            with tempfile.NamedTemporaryFile(delete=False) as temp_file:
                sha256_hash = hashlib.sha256()
                sha512_hash = hashlib.sha512()
                total_size = 0
                
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        temp_file.write(chunk)
                        sha256_hash.update(chunk)
                        sha512_hash.update(chunk)
                        total_size += len(chunk)
                
                temp_file_path = temp_file.name
            
            # Verify file integrity
            expected_hashes = target_info["hashes"]
            expected_size = target_info["length"]
            
            if total_size != expected_size:
                os.unlink(temp_file_path)
                raise Exception(f"Size mismatch: expected {expected_size}, got {total_size}")
            
            if sha256_hash.hexdigest() != expected_hashes["sha256"]:
                os.unlink(temp_file_path)
                raise Exception("SHA256 hash mismatch")
            
            if sha512_hash.hexdigest() != expected_hashes["sha512"]:
                os.unlink(temp_file_path)
                raise Exception("SHA512 hash mismatch")
            
            print(f"Target verified: {target_name} ({total_size} bytes)")
            return temp_file_path
            
        except requests.RequestException as e:
            raise Exception(f"Failed to download {target_name}: {e}")
    
    def list_available_updates(self):
        """List available updates from targets metadata"""
        targets_metadata = self.update_metadata()
        targets = targets_metadata["signed"]["targets"]
        
        print(f"Available updates ({len(targets)}):")
        for target_name, target_info in targets.items():
            size = target_info["length"]
            created = target_info.get("custom", {}).get("created_at", "Unknown")
            print(f"  {target_name} ({size} bytes, created: {created})")
        
        return targets
    
    def install_update(self, target_name, install_path=None):
        """Install a specific update"""
        targets_metadata = self.update_metadata()
        targets = targets_metadata["signed"]["targets"]
        
        if target_name not in targets:
            raise Exception(f"Target not found: {target_name}")
        
        target_info = targets[target_name]
        
        # Download and verify target
        temp_file = self.download_target(target_name, target_info)
        
        try:
            # Determine install path
            if install_path is None:
                install_path = f"/tmp/updates/{target_name}"
            
            install_dir = Path(install_path).parent
            install_dir.mkdir(parents=True, exist_ok=True)
            
            # Move to final location
            os.rename(temp_file, install_path)
            
            print(f"Update installed: {install_path}")
            return install_path
            
        except Exception as e:
            # Clean up on failure
            if os.path.exists(temp_file):
                os.unlink(temp_file)
            raise e

def main():
    """Main function for command line usage"""
    if len(sys.argv) < 2:
        print("Usage: tuf-client-updater.py <command> [args...]")
        print("Commands:")
        print("  init [root.json]           - Initialize root trust")
        print("  list                       - List available updates")
        print("  install <target>           - Install specific update")
        print("  update-metadata            - Update metadata only")
        sys.exit(1)
    
    try:
        client = TUFClient()
        command = sys.argv[1]
        
        if command == "init":
            root_file = sys.argv[2] if len(sys.argv) > 2 else None
            client.initialize_root_trust(root_file)
            
        elif command == "list":
            client.list_available_updates()
            
        elif command == "install":
            if len(sys.argv) < 3:
                print("Error: install requires a target name")
                sys.exit(1)
            
            target_name = sys.argv[2]
            install_path = sys.argv[3] if len(sys.argv) > 3 else None
            client.install_update(target_name, install_path)
            
        elif command == "update-metadata":
            client.update_metadata()
            print("Metadata updated successfully")
            
        else:
            print(f"Unknown command: {command}")
            sys.exit(1)
            
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()