import yaml
import os
import graphviz
from pathlib import Path
from typing import Dict, List, Set, Any

class InfluxDBRoleAnalyzer:
    def __init__(self, role_path: str):
        self.role_path = Path(role_path)
        self.tags = set()
        self.dependencies = []
        self.variables = {}
        self.handlers = set()
        self.state_flows = {
            'present': {
                'conditions': [],
                'tasks': [],
                'variables': set(),
                'dependencies': set()
            },
            'absent': {
                'conditions': [],
                'tasks': [],
                'variables': set(),
                'dependencies': set()
            }
        }
        self.analysis_results = []

    def _analyze_task_conditions(self, task: Dict[str, Any]) -> List[str]:
        """Analyze when conditions in a task"""
        conditions = []
        if 'when' in task:
            when = task['when']
            if isinstance(when, str):
                conditions.append(when)
            elif isinstance(when, list):
                conditions.extend(when)
            # Extract variable names from conditions
            for condition in conditions:
                if 'influxdb_' in str(condition):
                    var_name = str(condition).split()[0]
                    if var_name.startswith('influxdb_'):
                        self.state_flows[self._determine_state(condition)]['variables'].add(var_name)
        return conditions

    def _determine_state(self, condition: str) -> str:
        """Determine which state a condition belongs to"""
        condition = str(condition)
        if 'influxdb_state == present' in condition:
            return 'present'
        elif 'influxdb_state == absent' in condition:
            return 'absent'
        return 'unknown'

    def _analyze_task_dependencies(self, task: Dict[str, Any], state: str):
        """Analyze task dependencies based on variables and includes"""
        if 'include_tasks' in task:
            included_file = task['include_tasks']
            if isinstance(included_file, str):
                self.state_flows[state]['dependencies'].add(included_file)
        
        # Check for variable usage in task
        task_str = str(task)
        for var in [key for key in self.variables.get('defaults', {}).get('variables', {}).keys()]:
            if var in task_str:
                self.state_flows[state]['variables'].add(var)

    def analyze_role(self):
        """Analyze the complete role with state awareness"""
        try:
            self._analyze_variables()
            self._analyze_main_tasks()
            self._analyze_included_tasks()
            self._analyze_handlers()
            self._generate_text_report()
            self._create_visualization()
        except Exception as e:
            print(f"Error analyzing role: {str(e)}")
            raise

    def _analyze_main_tasks(self):
        """Analyze main tasks file with state tracking"""
        main_tasks = self.role_path / 'tasks' / 'main.yml'
        if main_tasks.exists():
            try:
                with open(main_tasks) as f:
                    tasks = yaml.safe_load(f)
                    if tasks:
                        for task in tasks:
                            if isinstance(task, dict):
                                # Get task conditions
                                conditions = self._analyze_task_conditions(task)
                                state = self._determine_state(str(conditions))
                                
                                if state in ['present', 'absent']:
                                    # Store task information
                                    task_info = {
                                        'name': task.get('name', 'unnamed task'),
                                        'conditions': conditions,
                                        'file': 'main.yml'
                                    }
                                    self.state_flows[state]['tasks'].append(task_info)
                                    
                                    # Analyze dependencies
                                    self._analyze_task_dependencies(task, state)
                                
                                # Collect tags
                                if 'tags' in task:
                                    self.tags.update(task['tags'] if isinstance(task['tags'], list) else [task['tags']])
            except Exception as e:
                print(f"Error analyzing main tasks: {str(e)}")
                raise

    def _analyze_included_tasks(self):
        """Analyze included task files"""
        tasks_dir = self.role_path / 'tasks'
        if tasks_dir.exists():
            for task_file in tasks_dir.glob('*.yml'):
                if task_file.name != 'main.yml':
                    try:
                        with open(task_file) as f:
                            tasks = yaml.safe_load(f)
                            if tasks:
                                for task in tasks:
                                    if isinstance(task, dict):
                                        conditions = self._analyze_task_conditions(task)
                                        state = self._determine_state(str(conditions))
                                        
                                        if state in ['present', 'absent']:
                                            task_info = {
                                                'name': task.get('name', 'unnamed task'),
                                                'conditions': conditions,
                                                'file': task_file.name
                                            }
                                            self.state_flows[state]['tasks'].append(task_info)
                                            self._analyze_task_dependencies(task, state)
                    except Exception as e:
                        print(f"Error analyzing included task file {task_file}: {str(e)}")

    def _generate_text_report(self):
        """Generate detailed text report with state flows"""
        report = []
        
        report.append("=== InfluxDB Role State Analysis Report ===\n")
        
        for state in ['present', 'absent']:
            report.append(f"\nState: {state}")
            report.append("=" * (len(state) + 7))
            
            # Variables used in this state
            report.append("\nVariables:")
            for var in sorted(self.state_flows[state]['variables']):
                report.append(f"  ├── {var}")
            
            # Tasks in this state
            report.append("\nTasks:")
            for task in self.state_flows[state]['tasks']:
                report.append(f"  ├── {task['name']} ({task['file']})")
                if task['conditions']:
                    report.append(f"  │   ├── Conditions: {', '.join(task['conditions'])}")
            
            # Dependencies for this state
            report.append("\nDependencies:")
            for dep in sorted(self.state_flows[state]['dependencies']):
                report.append(f"  ├── {dep}")
            
            report.append("")

        self.analysis_results = '\n'.join(report)

    def _create_visualization(self):
        """Generate state-aware visual representation"""
        dot = graphviz.Digraph(comment='InfluxDB Role State Flow')
        dot.attr(rankdir='LR')
        
        for state in ['present', 'absent']:
            with dot.subgraph(name=f'cluster_{state}') as c:
                c.attr(label=f'State: {state}')
                
                # Add variables
                for var in self.state_flows[state]['variables']:
                    c.node(f'{state}_{var}', var)
                
                # Add tasks with dependencies
                prev_task = None
                for task in self.state_flows[state]['tasks']:
                    task_id = f"{state}_{task['name']}"
                    c.node(task_id, task['name'])
                    if prev_task:
                        c.edge(prev_task, task_id)
                    prev_task = task_id
        
        dot.render('influxdb_role_state_flow', format='svg', cleanup=True)

def analyze_influxdb_role(role_path: str):
    """Main function with enhanced state analysis"""
    try:
        print(f"Analyzing role at: {role_path}\n")
        
        analyzer = InfluxDBRoleAnalyzer(role_path)
        analyzer.analyze_role()
        
        # Output reports
        print(analyzer.analysis_results)
        with open('influxdb_role_analysis.txt', 'w') as f:
            f.write(analyzer.analysis_results)
        print("\nText analysis report saved to: influxdb_role_analysis.txt")
        print("Visual analysis saved to: influxdb_role_state_flow.svg")
        
    except Exception as e:
        print(f"Error during role analysis: {str(e)}")
        raise

if __name__ == "__main__":
    analyze_influxdb_role('/home/lavender/sandbox/ansible/LabProvisioning/ProvisionCollection/influxdb')
    