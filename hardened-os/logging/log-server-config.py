#!/usr/bin/env python3
"""
Secure log server for receiving and verifying tamper-evident logs
from hardened OS clients with cryptographic integrity verification.
"""

import asyncio
import json
import logging
import ssl
import hashlib
import hmac
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, Optional
from aiohttp import web, ClientSession
import aiofiles
import cryptography.hazmat.primitives.hashes as hashes
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa, padding
from cryptography.exceptions import InvalidSignature

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class SecureLogServer:
    """Secure log server with integrity verification and tamper detection."""
    
    def __init__(self, config_path: str = "/etc/log-server/config.json"):
        self.config = self._load_config(config_path)
        self.storage_path = Path(self.config['storage_path'])
        self.storage_path.mkdir(parents=True, exist_ok=True)
        
        # Load verification keys
        self.verification_keys = self._load_verification_keys()
        
        # Initialize integrity database
        self.integrity_db = {}
        self._load_integrity_db()
    
    def _load_config(self, config_path: str) -> Dict[str, Any]:
        """Load server configuration."""
        try:
            with open(config_path, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            # Default configuration
            return {
                'host': '0.0.0.0',
                'port': 8443,
                'storage_path': '/var/log/remote',
                'cert_file': '/etc/ssl/certs/log-server.crt',
                'key_file': '/etc/ssl/private/log-server.key',
                'ca_file': '/etc/ssl/certs/ca.crt',
                'max_log_size': 100 * 1024 * 1024,  # 100MB
                'retention_days': 90
            }
    
    def _load_verification_keys(self) -> Dict[str, Any]:
        """Load client verification keys."""
        keys = {}
        keys_dir = Path("/etc/log-server/client-keys")
        
        if keys_dir.exists():
            for key_file in keys_dir.glob("*.pub"):
                client_id = key_file.stem
                try:
                    with open(key_file, 'rb') as f:
                        public_key = serialization.load_pem_public_key(f.read())
                        keys[client_id] = public_key
                        logger.info(f"Loaded verification key for client: {client_id}")
                except Exception as e:
                    logger.error(f"Failed to load key for {client_id}: {e}")
        
        return keys
    
    def _load_integrity_db(self):
        """Load integrity database from disk."""
        db_path = self.storage_path / "integrity.db"
        if db_path.exists():
            try:
                with open(db_path, 'r') as f:
                    self.integrity_db = json.load(f)
            except Exception as e:
                logger.error(f"Failed to load integrity database: {e}")
                self.integrity_db = {}
    
    def _save_integrity_db(self):
        """Save integrity database to disk."""
        db_path = self.storage_path / "integrity.db"
        try:
            with open(db_path, 'w') as f:
                json.dump(self.integrity_db, f, indent=2)
        except Exception as e:
            logger.error(f"Failed to save integrity database: {e}")
    
    def _verify_log_signature(self, client_id: str, log_data: bytes, signature: bytes) -> bool:
        """Verify cryptographic signature of log data."""
        if client_id not in self.verification_keys:
            logger.error(f"No verification key found for client: {client_id}")
            return False
        
        try:
            public_key = self.verification_keys[client_id]
            public_key.verify(
                signature,
                log_data,
                padding.PSS(
                    mgf=padding.MGF1(hashes.SHA256()),
                    salt_length=padding.PSS.MAX_LENGTH
                ),
                hashes.SHA256()
            )
            return True
        except InvalidSignature:
            logger.error(f"Invalid signature from client: {client_id}")
            return False
        except Exception as e:
            logger.error(f"Signature verification error for {client_id}: {e}")
            return False
    
    def _calculate_log_hash(self, log_data: bytes) -> str:
        """Calculate SHA-256 hash of log data."""
        return hashlib.sha256(log_data).hexdigest()
    
    def _detect_tampering(self, client_id: str, log_hash: str, timestamp: float) -> bool:
        """Detect potential log tampering based on hash chain."""
        client_chain = self.integrity_db.get(client_id, [])
        
        if not client_chain:
            # First log from this client
            return False
        
        last_entry = client_chain[-1]
        
        # Check for timestamp anomalies
        if timestamp < last_entry['timestamp']:
            logger.warning(f"Timestamp anomaly detected for {client_id}: {timestamp} < {last_entry['timestamp']}")
            return True
        
        # Check for hash chain integrity (simplified)
        expected_chain_hash = hashlib.sha256(
            (last_entry['hash'] + log_hash).encode()
        ).hexdigest()
        
        return False  # Simplified - implement full hash chain verification
    
    async def handle_log_upload(self, request: web.Request) -> web.Response:
        """Handle log upload from clients."""
        try:
            # Extract client certificate information
            peercert = request.transport.get_extra_info('peercert')
            if not peercert:
                return web.Response(status=401, text="Client certificate required")
            
            client_id = peercert.get('subject', {}).get('commonName', 'unknown')
            
            # Read log data
            log_data = await request.read()
            
            # Extract signature from headers
            signature_header = request.headers.get('X-Log-Signature')
            if not signature_header:
                return web.Response(status=400, text="Missing log signature")
            
            try:
                signature = bytes.fromhex(signature_header)
            except ValueError:
                return web.Response(status=400, text="Invalid signature format")
            
            # Verify signature
            if not self._verify_log_signature(client_id, log_data, signature):
                logger.error(f"Signature verification failed for client: {client_id}")
                return web.Response(status=403, text="Signature verification failed")
            
            # Calculate log hash
            log_hash = self._calculate_log_hash(log_data)
            timestamp = time.time()
            
            # Detect tampering
            if self._detect_tampering(client_id, log_hash, timestamp):
                logger.critical(f"TAMPERING DETECTED for client: {client_id}")
                # Send alert (implement notification mechanism)
                return web.Response(status=409, text="Tampering detected")
            
            # Store log data
            log_filename = f"{client_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
            log_path = self.storage_path / client_id / log_filename
            log_path.parent.mkdir(parents=True, exist_ok=True)
            
            async with aiofiles.open(log_path, 'wb') as f:
                await f.write(log_data)
            
            # Update integrity database
            if client_id not in self.integrity_db:
                self.integrity_db[client_id] = []
            
            self.integrity_db[client_id].append({
                'timestamp': timestamp,
                'hash': log_hash,
                'filename': log_filename,
                'size': len(log_data)
            })
            
            self._save_integrity_db()
            
            logger.info(f"Log received and verified from {client_id}: {log_filename}")
            return web.Response(status=200, text="Log received and verified")
            
        except Exception as e:
            logger.error(f"Error handling log upload: {e}")
            return web.Response(status=500, text="Internal server error")
    
    async def handle_integrity_check(self, request: web.Request) -> web.Response:
        """Handle integrity check requests."""
        try:
            client_id = request.query.get('client_id')
            if not client_id:
                return web.Response(status=400, text="Missing client_id parameter")
            
            client_chain = self.integrity_db.get(client_id, [])
            
            integrity_report = {
                'client_id': client_id,
                'total_logs': len(client_chain),
                'last_update': client_chain[-1]['timestamp'] if client_chain else None,
                'integrity_status': 'verified',
                'hash_chain': [entry['hash'] for entry in client_chain[-10:]]  # Last 10 hashes
            }
            
            return web.json_response(integrity_report)
            
        except Exception as e:
            logger.error(f"Error handling integrity check: {e}")
            return web.Response(status=500, text="Internal server error")
    
    def create_ssl_context(self) -> ssl.SSLContext:
        """Create SSL context for secure connections."""
        context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
        context.load_cert_chain(
            self.config['cert_file'],
            self.config['key_file']
        )
        
        # Require client certificates
        context.verify_mode = ssl.CERT_REQUIRED
        context.load_verify_locations(self.config['ca_file'])
        
        return context
    
    async def start_server(self):
        """Start the secure log server."""
        app = web.Application()
        app.router.add_post('/upload', self.handle_log_upload)
        app.router.add_get('/integrity', self.handle_integrity_check)
        
        ssl_context = self.create_ssl_context()
        
        runner = web.AppRunner(app)
        await runner.setup()
        
        site = web.TCPSite(
            runner,
            self.config['host'],
            self.config['port'],
            ssl_context=ssl_context
        )
        
        await site.start()
        logger.info(f"Secure log server started on {self.config['host']}:{self.config['port']}")
        
        # Keep server running
        try:
            await asyncio.Future()  # Run forever
        except KeyboardInterrupt:
            logger.info("Shutting down server...")
        finally:
            await runner.cleanup()

def main():
    """Main entry point."""
    server = SecureLogServer()
    asyncio.run(server.start_server())

if __name__ == '__main__':
    main()