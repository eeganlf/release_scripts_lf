# WARNING: NOT FULLY TESTED. MAY MISS SOME COMMANDS
# To run place this file in the same directory as the LaTeX file:
# python latex-command-extractor.py file.tex output.txt
import re

def clean_command(cmd):
    """Clean a command line of prompt characters and extra whitespace"""
    # Remove LaTeX formatting first
    cmd = re.sub(r'˜', '', cmd)
    
    # Remove any remaining prompt symbols and their whitespace
    cmd = re.sub(r'^[~#$]\s*', '', cmd.strip())
    
    # Handle cases where the prompt symbol might appear after other characters
    cmd = re.sub(r'[~#$]\s+', '', cmd)
    
    # Remove any "~# " or "$ " that might appear in the middle of the command
    cmd = re.sub(r'\s*[~#$]\s*', ' ', cmd)
    
    return cmd.strip()

def get_prompt_info(line):
    """Get node type and user from a prompt line"""
    # Handle both normal prompts and those with LaTeX formatting
    line = re.sub(r'˜', '', line)  # Remove special LaTeX tilde
    
    if '@cp:' in line:
        node = 'Control plane'
    elif '@worker:' in line:
        node = 'Worker node'
    else:
        return None, None
        
    if line.startswith('root@'):
        user = 'root'
    elif line.startswith('student@'):
        user = 'student'
    else:
        return None, None
        
    return node, user

def process_command_block(block):
    """Process a single command block and extract commands"""
    commands = []
    current_node = None
    current_user = None
    current_command = []
    
    # Clean up the block
    lines = [line.strip() for line in block.split('\n')]
    i = 0
    
    while i < len(lines):
        line = lines[i].strip()
        
        if not line:
            i += 1
            continue
            
        # Check for prompt
        if '@cp:' in line or '@worker:' in line:
            # Process any pending command
            if current_command:
                commands.append((current_node, current_user, ' '.join(current_command)))
                current_command = []
            
            # Update context
            node, user = get_prompt_info(line)
            if node and user:
                current_node = node
                current_user = user
            
            # Get command part after the prompt
            parts = line.split(':', 1)
            if len(parts) > 1:
                cmd = parts[1].strip()
                if cmd:
                    current_command.append(clean_command(cmd))
                    
                    # If command contains && or |, it's complete
                    if '&&' in cmd or cmd.endswith('\\') or ' | ' in cmd:
                        pass  # Wait for more lines
                    else:
                        commands.append((current_node, current_user, ' '.join(current_command)))
                        current_command = []
        
        elif current_node and current_user:  # Not a prompt line
            cleaned = clean_command(line)
            if cleaned:
                current_command.append(cleaned)
                
                # If this line doesn't end with a backslash and the next line isn't indented
                # and doesn't start with a pipe, consider it a complete command
                next_line = lines[i + 1] if i + 1 < len(lines) else ''
                if not (line.endswith('\\') or 
                       next_line.startswith(' ') or 
                       next_line.lstrip().startswith('|') or
                       'EOF' in next_line):
                    commands.append((current_node, current_user, ' '.join(current_command)))
                    current_command = []
        
        i += 1
    
    # Process any remaining command
    if current_command:
        commands.append((current_node, current_user, ' '.join(current_command)))
    
    return commands

def process_latex_file(input_file, output_file):
    """Process LaTeX file and extract commands with context"""
    try:
        with open(input_file, 'r', encoding='utf-8') as file:
            content = file.read()
        
        # Find all command blocks
        cmd_pattern = r'\\begin{cmd}(.*?)\\end{cmd}'
        cmd_blocks = re.findall(cmd_pattern, content, re.DOTALL)
        
        all_commands = []
        for block in cmd_blocks:
            commands = process_command_block(block)
            all_commands.extend(commands)
        
        # Format output
        output_lines = []
        current_header = None
        
        for node, user, cmd in all_commands:
            header = f"{node} {user}"
            if header != current_header:
                output_lines.append(f"\n{header}:")
                current_header = header
            
            if cmd and not cmd.startswith('<') and not cmd.endswith('>'):
                output_lines.append(cmd)
        
        # Write output
        with open(output_file, 'w', encoding='utf-8') as file:
            file.write('\n'.join(output_lines).strip())
        
        # Print statistics
        print(f"Found {len(cmd_blocks)} command blocks")
        print(f"Extracted {len(all_commands)} commands")
        node_counts = {}
        for node, user, _ in all_commands:
            key = f"{node} {user}"
            node_counts[key] = node_counts.get(key, 0) + 1
        
        for key, count in node_counts.items():
            print(f"{key}: {count} commands")
        
        return True
        
    except Exception as e:
        print(f"Error processing file: {str(e)}")
        return False

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) != 3:
        print("Usage: python script.py <input_latex_file> <output_text_file>")
        sys.exit(1)
        
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    if process_latex_file(input_file, output_file):
        print(f"Commands successfully extracted to {output_file}")
    else:
        sys.exit(1)
