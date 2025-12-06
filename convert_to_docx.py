#!/usr/bin/env python3
"""
Enhanced script to convert academic report from Markdown to Word (.docx) format
Requires: pip install python-docx
"""

from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
import re

def create_document():
    """Create a new Word document with proper formatting"""
    doc = Document()
    
    # Set document margins
    sections = doc.sections
    for section in sections:
        section.top_margin = Inches(1)
        section.bottom_margin = Inches(1)
        section.left_margin = Inches(1.25)
        section.right_margin = Inches(1.25)
    
    return doc

def clean_markdown_text(text):
    """Remove markdown formatting from text"""
    # Remove bold first
    text = re.sub(r'\*\*(.*?)\*\*', r'\1', text)
    # Remove italic (single asterisks, but not if part of bold)
    text = re.sub(r'(?<!\*)\*([^*]+?)\*(?!\*)', r'\1', text)
    # Remove inline code
    text = re.sub(r'`(.*?)`', r'\1', text)
    # Remove links
    text = re.sub(r'\[([^\]]+)\]\([^\)]+\)', r'\1', text)
    return text.strip()

def add_formatted_text(para, text):
    """Add text with preserved formatting"""
    # Split by markdown bold
    parts = re.split(r'(\*\*.*?\*\*)', text)
    for part in parts:
        if part.startswith('**') and part.endswith('**'):
            run = para.add_run(part[2:-2])
            run.bold = True
        else:
            para.add_run(part)

def parse_markdown_to_docx(md_file, docx_file):
    """Convert Markdown file to Word document"""
    doc = create_document()
    
    with open(md_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    lines = content.split('\n')
    i = 0
    in_code_block = False
    code_block_lines = []
    in_table = False
    table_lines = []
    current_list_type = None
    
    while i < len(lines):
        line = lines[i]
        original_line = line
        line_stripped = line.strip()
        
        # Handle code blocks
        if line_stripped.startswith('```'):
            if in_code_block:
                # End code block
                if code_block_lines:
                    para = doc.add_paragraph()
                    run = para.add_run('\n'.join(code_block_lines))
                    run.font.name = 'Courier New'
                    run.font.size = Pt(9)
                code_block_lines = []
                in_code_block = False
            else:
                in_code_block = True
            i += 1
            continue
        
        if in_code_block:
            if not line_stripped.startswith('```'):
                code_block_lines.append(line)
            i += 1
            continue
        
        # Handle tables
        if '|' in line and line_stripped and not line_stripped.startswith('#'):
            if not in_table:
                in_table = True
            table_lines.append(line)
            i += 1
            continue
        else:
            if in_table and table_lines:
                # Process table
                process_table(doc, table_lines)
                table_lines = []
                in_table = False
        
        # Skip empty lines (but add spacing after headings)
        if not line_stripped:
            i += 1
            continue
        
        # Handle horizontal rules
        if line_stripped == '---' or line_stripped.startswith('---'):
            doc.add_paragraph()
            i += 1
            continue
        
        # Handle headings
        if line_stripped.startswith('# '):
            heading = doc.add_heading(line_stripped[2:].strip(), level=1)
            current_list_type = None
        elif line_stripped.startswith('## '):
            heading = doc.add_heading(line_stripped[3:].strip(), level=2)
            current_list_type = None
        elif line_stripped.startswith('### '):
            heading = doc.add_heading(line_stripped[4:].strip(), level=3)
            current_list_type = None
        elif line_stripped.startswith('#### '):
            heading = doc.add_heading(line_stripped[5:].strip(), level=4)
            current_list_type = None
        elif line_stripped.startswith('##### '):
            heading = doc.add_heading(line_stripped[6:].strip(), level=5)
            current_list_type = None
        # Handle bold-only lines (metadata)
        elif line_stripped.startswith('**') and line_stripped.endswith('**'):
            para = doc.add_paragraph()
            text = clean_markdown_text(line_stripped)
            add_formatted_text(para, line_stripped)
            current_list_type = None
        # Handle numbered lists
        elif re.match(r'^\d+\.\s', line_stripped):
            text = re.sub(r'^\d+\.\s+', '', line_stripped)
            text = clean_markdown_text(text)
            para = doc.add_paragraph(text, style='List Number')
            current_list_type = 'numbered'
        # Handle bullet lists
        elif line_stripped.startswith('- ') or line_stripped.startswith('* '):
            text = line_stripped[2:].strip()
            text = clean_markdown_text(text)
            para = doc.add_paragraph(text, style='List Bullet')
            current_list_type = 'bullet'
        # Regular paragraph
        else:
            # Check if it's a continuation of a list item (indented)
            if line.startswith('   ') or line.startswith('\t'):
                if current_list_type:
                    text = line_stripped
                    text = clean_markdown_text(text)
                    para = doc.add_paragraph(text, style='List Bullet' if current_list_type == 'bullet' else 'List Number')
                else:
                    text = clean_markdown_text(line_stripped)
                    if text:
                        para = doc.add_paragraph(text)
                        add_formatted_text(para, line_stripped)
            else:
                text = clean_markdown_text(line_stripped)
                if text:
                    para = doc.add_paragraph()
                    add_formatted_text(para, line_stripped)
                current_list_type = None
        
        i += 1
    
    # Handle any remaining code block or table
    if code_block_lines:
        para = doc.add_paragraph()
        run = para.add_run('\n'.join(code_block_lines))
        run.font.name = 'Courier New'
        run.font.size = Pt(9)
    
    if table_lines:
        process_table(doc, table_lines)
    
    # Save document
    doc.save(docx_file)
    print(f"✓ Successfully created {docx_file}")

def process_table(doc, table_lines):
    """Process markdown table and add to document"""
    # Filter out empty lines and separator lines
    data_lines = []
    for line in table_lines:
        stripped = line.strip()
        if stripped and not re.match(r'^[\|\s\-:]+$', stripped):
            data_lines.append(stripped)
    
    if len(data_lines) < 1:
        return
    
    # Parse header
    header_line = data_lines[0]
    headers = [cell.strip() for cell in header_line.split('|') if cell.strip()]
    
    if not headers:
        return
    
    # Create table
    table = doc.add_table(rows=1, cols=len(headers))
    table.style = 'Light Grid Accent 1'
    
    # Add header row
    header_cells = table.rows[0].cells
    for i, header_text in enumerate(headers):
        header_cells[i].text = clean_markdown_text(header_text)
        # Make header bold
        for paragraph in header_cells[i].paragraphs:
            for run in paragraph.runs:
                run.font.bold = True
    
    # Add data rows
    for line in data_lines[1:]:
        cells = [cell.strip() for cell in line.split('|') if cell.strip()]
        if len(cells) == len(headers):
            row = table.add_row()
            for i, cell_text in enumerate(cells):
                row.cells[i].text = clean_markdown_text(cell_text)

if __name__ == '__main__':
    try:
        parse_markdown_to_docx('Academic_Report.md', 'Final_Report.docx')
        print("\nDocument created successfully!")
        print("You can now open 'Final_Report.docx' in Microsoft Word.")
    except FileNotFoundError:
        print("Error: Academic_Report.md not found!")
    except ImportError:
        print("Error: python-docx library not installed!")
        print("Please install it using: pip install python-docx")
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()

