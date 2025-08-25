#!/usr/bin/env python3

"""
Staged Rollout Manager
Manages staged rollouts and health check mechanisms for secure updates
Requirement 8.5: Staged rollouts with canary testing
"""

import os
import json
import sys
import time
import subprocess
from pathlib import Path
from datetime import datetime, timedelta
import hashlib
import random

class StagedRolloutManager:
    def __init__(self, config_dir="/etc/tuf/rollout"):
        self.config_dir = Path(config_dir)
        self.config_dir.mkdir(parents=True, exist_ok=True)
        
        # Rollout configuration
        self.rollout_config_file = self.config_dir / "rollout-config.json"
        self.rollout_state_file = self.config_dir / "rollout-state.json"
        
        # Default rollout stages
        self.default_stages = [
            {"name": "canary", "percentage": 1, "duration_hours": 24},
            {"name": "early", "percentage": 10, "duration_hours": 48},
            {"name": "gradual", "percentage": 50, "duration_hours": 72},
            {"name": "full", "percentage": 100, "duration_hours": 0}
        ]
        
        self.load_config()
    
    def load_config(self):
        """Load rollout configuration"""
        if self.rollout_config_file.exists():
            with open(self.rollout_config_file, 'r') as f:
                self.config = json.load(f)
        else:
            self.config = {
                "stages": self.default_stages,
                "health_checks": {
                    "enabled": True,
                    "failure_threshold": 5,
                    "success_threshold": 95
                },
                "rollback": {
                    "enabled": True,
                    "automatic": True
                }
            }
            self.save_config()
    
    def save_config(self):
        """Save rollout configuration"""
        with open(self.rollout_config_file, 'w') as f:
            json.dump(self.config, f, indent=2)
    
    def load_rollout_state(self):
        """Load current rollout state"""
        if self.rollout_state_file.exists():
            with open(self.rollout_state_file, 'r') as f:
                return json.load(f)
        return None
    
    def save_rollout_state(self, state):
        """Save rollout state"""
        with open(self.rollout_state_file, 'w') as f:
            json.dump(state, f, indent=2)
    
    def get_system_id(self):
        """Generate consistent system ID for rollout selection"""
        # Use machine ID or generate from hardware info
        machine_id_file = Path("/etc/machine-id")
        if machine_id_file.exists():
            with open(machine_id_file, 'r') as f:
                machine_id = f.read().strip()
        else:
            # Fallback: generate from hostname and other system info
            hostname = subprocess.check_output(['hostname']).decode().strip()
            machine_id = hashlib.sha256(hostname.encode()).hexdigest()
        
        return machine_id
    
    def calculate_rollout_group(self, update_id, system_id):
        """Calculate which rollout group this system belongs to"""
        # Create deterministic hash from update ID and system ID
        combined = f"{update_id}:{system_id}"
        hash_value = hashlib.sha256(combined.encode()).hexdigest()
        
        # Convert to percentage (0-99)
        percentage = int(hash_value[:8], 16) % 100
        
        return percentage
    
    def get_current_stage(self, rollout_percentage, rollout_start_time):
        """Determine current rollout stage based on time and configuration"""
        current_time = datetime.utcnow()
        elapsed_hours = (current_time - rollout_start_time).total_seconds() / 3600
        
        cumulative_percentage = 0
        cumulative_hours = 0
        
        for stage in self.config["stages"]:
            cumulative_percentage = stage["percentage"]
            cumulative_hours += stage["duration_hours"]
            
            # Check if we're in this stage's time window and percentage
            if (elapsed_hours <= cumulative_hours or stage["duration_hours"] == 0) and \
               rollout_percentage < cumulative_percentage:
                return stage
        
        # Default to full rollout if we've passed all stages
        return self.config["stages"][-1]
    
    def check_system_health(self):
        """Perform system health checks"""
        health_results = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "checks": {},
            "overall_status": "healthy"
        }
        
        # Check 1: System load
        try:
            with open('/proc/loadavg', 'r') as f:
                load_avg = float(f.read().split()[0])
            
            health_results["checks"]["load_average"] = {
                "value": load_avg,
                "status": "healthy" if load_avg < 2.0 else "warning" if load_avg < 5.0 else "critical"
            }
        except:
            health_results["checks"]["load_average"] = {"status": "unknown"}
        
        # Check 2: Disk space
        try:
            result = subprocess.run(['df', '/'], capture_output=True, text=True)
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                if len(lines) > 1:
                    fields = lines[1].split()
                    used_percent = int(fields[4].rstrip('%'))
                    
                    health_results["checks"]["disk_space"] = {
                        "used_percent": used_percent,
                        "status": "healthy" if used_percent < 80 else "warning" if used_percent < 95 else "critical"
                    }
        except:
            health_results["checks"]["disk_space"] = {"status": "unknown"}
        
        # Check 3: Memory usage
        try:
            with open('/proc/meminfo', 'r') as f:
                meminfo = f.read()
            
            mem_total = None
            mem_available = None
            
            for line in meminfo.split('\n'):
                if line.startswith('MemTotal:'):
                    mem_total = int(line.split()[1])
                elif line.startswith('MemAvailable:'):
                    mem_available = int(line.split()[1])
            
            if mem_total and mem_available:
                used_percent = ((mem_total - mem_available) / mem_total) * 100
                
                health_results["checks"]["memory_usage"] = {
                    "used_percent": round(used_percent, 2),
                    "status": "healthy" if used_percent < 80 else "warning" if used_percent < 95 else "critical"
                }
        except:
            health_results["checks"]["memory_usage"] = {"status": "unknown"}
        
        # Check 4: Critical services
        critical_services = ["systemd", "networkd", "nftables"]
        service_status = {}
        
        for service in critical_services:
            try:
                result = subprocess.run(['systemctl', 'is-active', service], 
                                      capture_output=True, text=True)
                service_status[service] = "active" if result.returncode == 0 else "inactive"
            except:
                service_status[service] = "unknown"
        
        health_results["checks"]["critical_services"] = {
            "services": service_status,
            "status": "healthy" if all(s == "active" for s in service_status.values()) else "critical"
        }
        
        # Determine overall status
        check_statuses = [check.get("status", "unknown") for check in health_results["checks"].values()]
        
        if "critical" in check_statuses:
            health_results["overall_status"] = "critical"
        elif "warning" in check_statuses:
            health_results["overall_status"] = "warning"
        elif "unknown" in check_statuses:
            health_results["overall_status"] = "unknown"
        else:
            health_results["overall_status"] = "healthy"
        
        return health_results
    
    def should_receive_update(self, update_id):
        """Determine if this system should receive the update based on rollout stage"""
        system_id = self.get_system_id()
        rollout_percentage = self.calculate_rollout_group(update_id, system_id)
        
        # Load rollout state
        rollout_state = self.load_rollout_state()
        
        if not rollout_state or rollout_state.get("update_id") != update_id:
            # New rollout or different update
            print(f"No active rollout for update {update_id}")
            return False, None
        
        rollout_start_time = datetime.fromisoformat(rollout_state["start_time"].rstrip('Z'))
        current_stage = self.get_current_stage(rollout_percentage, rollout_start_time)
        
        # Check if system is in current rollout group
        eligible = rollout_percentage < current_stage["percentage"]
        
        return eligible, {
            "system_id": system_id[:16] + "...",
            "rollout_percentage": rollout_percentage,
            "current_stage": current_stage["name"],
            "stage_percentage": current_stage["percentage"],
            "eligible": eligible
        }
    
    def start_rollout(self, update_id, update_info):
        """Start a new staged rollout"""
        rollout_state = {
            "update_id": update_id,
            "update_info": update_info,
            "start_time": datetime.utcnow().isoformat() + "Z",
            "status": "active",
            "health_reports": [],
            "rollback_triggered": False
        }
        
        self.save_rollout_state(rollout_state)
        
        print(f"Started rollout for update: {update_id}")
        print(f"Rollout stages: {len(self.config['stages'])}")
        
        for i, stage in enumerate(self.config["stages"]):
            print(f"  Stage {i+1}: {stage['name']} ({stage['percentage']}% over {stage['duration_hours']}h)")
        
        return rollout_state
    
    def report_health(self, update_id):
        """Report system health for current rollout"""
        rollout_state = self.load_rollout_state()
        
        if not rollout_state or rollout_state.get("update_id") != update_id:
            raise Exception(f"No active rollout for update {update_id}")
        
        # Perform health check
        health_results = self.check_system_health()
        
        # Add to rollout state
        rollout_state["health_reports"].append(health_results)
        
        # Keep only recent reports (last 100)
        rollout_state["health_reports"] = rollout_state["health_reports"][-100:]
        
        self.save_rollout_state(rollout_state)
        
        print(f"Health report submitted: {health_results['overall_status']}")
        
        # Check if rollback should be triggered
        if self.config["rollback"]["enabled"] and self.config["rollback"]["automatic"]:
            self.check_rollback_conditions(rollout_state)
        
        return health_results
    
    def check_rollback_conditions(self, rollout_state):
        """Check if rollback should be triggered based on health reports"""
        recent_reports = rollout_state["health_reports"][-10:]  # Last 10 reports
        
        if len(recent_reports) < 5:
            return  # Not enough data
        
        critical_count = sum(1 for report in recent_reports if report["overall_status"] == "critical")
        failure_rate = (critical_count / len(recent_reports)) * 100
        
        failure_threshold = self.config["health_checks"]["failure_threshold"]
        
        if failure_rate > failure_threshold:
            print(f"Rollback triggered: failure rate {failure_rate}% > threshold {failure_threshold}%")
            self.trigger_rollback(rollout_state)
    
    def trigger_rollback(self, rollout_state):
        """Trigger rollback for current rollout"""
        rollout_state["rollback_triggered"] = True
        rollout_state["rollback_time"] = datetime.utcnow().isoformat() + "Z"
        rollout_state["status"] = "rolled_back"
        
        self.save_rollout_state(rollout_state)
        
        print("ROLLBACK TRIGGERED - Update rollout has been stopped")
        
        # In a full implementation, this would trigger actual rollback procedures
        # For now, we just mark the rollout as rolled back
    
    def get_rollout_status(self, update_id=None):
        """Get current rollout status"""
        rollout_state = self.load_rollout_state()
        
        if not rollout_state:
            return {"status": "no_active_rollout"}
        
        if update_id and rollout_state.get("update_id") != update_id:
            return {"status": "no_rollout_for_update", "update_id": update_id}
        
        # Calculate current stage
        rollout_start_time = datetime.fromisoformat(rollout_state["start_time"].rstrip('Z'))
        current_time = datetime.utcnow()
        elapsed_hours = (current_time - rollout_start_time).total_seconds() / 3600
        
        # Find current stage
        current_stage = None
        cumulative_hours = 0
        
        for stage in self.config["stages"]:
            cumulative_hours += stage["duration_hours"]
            if elapsed_hours <= cumulative_hours or stage["duration_hours"] == 0:
                current_stage = stage
                break
        
        if not current_stage:
            current_stage = self.config["stages"][-1]
        
        # Health summary
        recent_reports = rollout_state["health_reports"][-10:]
        health_summary = {
            "total_reports": len(rollout_state["health_reports"]),
            "recent_reports": len(recent_reports),
            "healthy_count": sum(1 for r in recent_reports if r["overall_status"] == "healthy"),
            "warning_count": sum(1 for r in recent_reports if r["overall_status"] == "warning"),
            "critical_count": sum(1 for r in recent_reports if r["overall_status"] == "critical")
        }
        
        return {
            "status": rollout_state["status"],
            "update_id": rollout_state["update_id"],
            "start_time": rollout_state["start_time"],
            "elapsed_hours": round(elapsed_hours, 2),
            "current_stage": current_stage,
            "rollback_triggered": rollout_state.get("rollback_triggered", False),
            "health_summary": health_summary
        }

def main():
    """Main function for command line usage"""
    if len(sys.argv) < 2:
        print("Usage: staged-rollout-manager.py <command> [args...]")
        print("Commands:")
        print("  start <update_id> <update_info>  - Start rollout")
        print("  check <update_id>                - Check if system should receive update")
        print("  health <update_id>               - Report health for rollout")
        print("  status [update_id]               - Get rollout status")
        print("  rollback <update_id>             - Trigger manual rollback")
        sys.exit(1)
    
    try:
        manager = StagedRolloutManager()
        command = sys.argv[1]
        
        if command == "start":
            if len(sys.argv) < 4:
                print("Error: start requires update_id and update_info")
                sys.exit(1)
            
            update_id = sys.argv[2]
            update_info = sys.argv[3]
            manager.start_rollout(update_id, update_info)
            
        elif command == "check":
            if len(sys.argv) < 3:
                print("Error: check requires update_id")
                sys.exit(1)
            
            update_id = sys.argv[2]
            eligible, info = manager.should_receive_update(update_id)
            
            print(f"Update eligibility for {update_id}:")
            if info:
                for key, value in info.items():
                    print(f"  {key}: {value}")
            else:
                print("  No active rollout")
                
        elif command == "health":
            if len(sys.argv) < 3:
                print("Error: health requires update_id")
                sys.exit(1)
            
            update_id = sys.argv[2]
            health_results = manager.report_health(update_id)
            
            print(f"Health check results:")
            print(f"  Overall status: {health_results['overall_status']}")
            for check_name, check_result in health_results["checks"].items():
                print(f"  {check_name}: {check_result['status']}")
                
        elif command == "status":
            update_id = sys.argv[2] if len(sys.argv) > 2 else None
            status = manager.get_rollout_status(update_id)
            
            print("Rollout status:")
            for key, value in status.items():
                if isinstance(value, dict):
                    print(f"  {key}:")
                    for sub_key, sub_value in value.items():
                        print(f"    {sub_key}: {sub_value}")
                else:
                    print(f"  {key}: {value}")
                    
        elif command == "rollback":
            if len(sys.argv) < 3:
                print("Error: rollback requires update_id")
                sys.exit(1)
            
            update_id = sys.argv[2]
            rollout_state = manager.load_rollout_state()
            
            if rollout_state and rollout_state.get("update_id") == update_id:
                manager.trigger_rollback(rollout_state)
            else:
                print(f"No active rollout found for update {update_id}")
                
        else:
            print(f"Unknown command: {command}")
            sys.exit(1)
            
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()