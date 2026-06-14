import re

files = [
    '/Users/chandanaroy7/Documents/FileCounterApp/HardwareAnalyzer.swift',
    '/Users/chandanaroy7/Documents/FileCounterApp/ActivityMonitor.swift',
    '/Users/chandanaroy7/Documents/FileCounterApp/LivePowerMonitor.swift',
    '/Users/chandanaroy7/Documents/FileCounterApp/NetworkMonitor.swift'
]

for file in files:
    with open(file, 'r') as f:
        content = f.read()
    
    # Replace .animation(.spring(...)) with .animation(.easeOut(duration: 0.3)...)
    content = re.sub(r'\.animation\(\.spring[^)]*\)', '.animation(.easeOut(duration: 0.3))', content)
    content = re.sub(r'\.animation\(\.spring[^)]*\),', '.animation(.easeOut(duration: 0.3)),', content)
    # Also catch cases like .animation(.spring, value: ...)
    content = re.sub(r'\.animation\(\.spring,\s*value:', '.animation(.easeOut(duration: 0.3), value:', content)
    
    with open(file, 'w') as f:
        f.write(content)

print("Animations fixed.")
