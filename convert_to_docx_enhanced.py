#!/usr/bin/env python3
"""
Enhanced script to convert academic report from Markdown to Word (.docx) format
Includes front page, page breaks, and proper formatting
Requires: pip install python-docx
"""

from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
import re

def add_page_break(paragraph):
    """Add a page break before a paragraph"""
    run = paragraph.runs[0] if paragraph.runs else paragraph.add_run()
    run.add_break(6)  # Page break

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

def add_front_page(doc):
    """Add a professional front page"""
    # Add spacing at top
    for _ in range(8):
        doc.add_paragraph()
    
    # Title
    title_para = doc.add_paragraph()
    title_para.alignment = WD_ALIGN_PARAGRAPH.CENTER
    title_run = title_para.add_run('Design and Implementation of a 3-Floor Elevator Control System\nUsing Freescale HC12 Microcontroller')
    title_run.font.size = Pt(18)
    title_run.font.bold = True
    title_run.font.name = 'Times New Roman'
    
    # Add spacing
    for _ in range(6):
        doc.add_paragraph()
    
    # Course information
    info_para = doc.add_paragraph()
    info_para.alignment = WD_ALIGN_PARAGRAPH.CENTER
    info_run = info_para.add_run('COE324 - Microcontroller Laboratory\nFinal Project Report')
    info_run.font.size = Pt(14)
    info_run.font.name = 'Times New Roman'
    
    # Add spacing
    for _ in range(8):
        doc.add_paragraph()
    
    # Student information section
    student_para = doc.add_paragraph()
    student_para.alignment = WD_ALIGN_PARAGRAPH.CENTER
    student_run = student_para.add_run('Submitted by:\n[Your Name]\n[Student ID]')
    student_run.font.size = Pt(12)
    student_run.font.name = 'Times New Roman'
    
    # Add spacing
    for _ in range(4):
        doc.add_paragraph()
    
    # Date
    date_para = doc.add_paragraph()
    date_para.alignment = WD_ALIGN_PARAGRAPH.CENTER
    date_run = date_para.add_run('[Date]')
    date_run.font.size = Pt(12)
    date_run.font.name = 'Times New Roman'
    
    # Add spacing
    for _ in range(6):
        doc.add_paragraph()
    
    # Department/University (if applicable)
    dept_para = doc.add_paragraph()
    dept_para.alignment = WD_ALIGN_PARAGRAPH.CENTER
    dept_run = dept_para.add_run('Department of Computer and Communications Engineering\nLebanese American University')
    dept_run.font.size = Pt(11)
    dept_run.font.italic = True
    dept_run.font.name = 'Times New Roman'
    
    # Page break after front page
    doc.add_page_break()

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
    
    # Add front page
    add_front_page(doc)
    
    with open(md_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    lines = content.split('\n')
    i = 0
    in_code_block = False
    code_block_lines = []
    in_table = False
    table_lines = []
    current_list_type = None
    last_was_major_heading = False
    
    # Sections that should have page breaks before them
    major_sections = ['Abstract', '1. Introduction', '2. System Overview', '3. Hardware Design', 
                      '4. Software Architecture', '5. Implementation Details', '6. Testing and Results',
                      '7. Discussion', '8. Conclusion', '9. References', 'Appendix']
    
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
            # Check if this should be a page break (after front page metadata)
            if i > 0 and 'Date' in lines[i-5:i+1]:
                doc.add_page_break()
            else:
                doc.add_paragraph()
            i += 1
            continue
        
        # Handle headings
        if line_stripped.startswith('# '):
            # Check if this is a major section that needs page break
            heading_text = line_stripped[2:].strip()
            if any(major in heading_text for major in ['Abstract', 'Introduction', 'System Overview', 
                                                       'Hardware Design', 'Software Architecture', 
                                                       'Implementation Details', 'Testing and Results',
                                                       'Discussion', 'Conclusion', 'References']):
                if not last_was_major_heading:  # Avoid double page breaks
                    doc.add_page_break()
            heading = doc.add_heading(heading_text, level=1)
            last_was_major_heading = True
            current_list_type = None
        elif line_stripped.startswith('## '):
            heading_text = line_stripped[3:].strip()
            # Check for major sections
            if any(major in heading_text for major in major_sections):
                if not last_was_major_heading:
                    doc.add_page_break()
            heading = doc.add_heading(heading_text, level=2)
            last_was_major_heading = (heading_text in major_sections or 
                                     any(major in heading_text for major in ['Appendix']))
            current_list_type = None
        elif line_stripped.startswith('### '):
            heading = doc.add_heading(line_stripped[4:].strip(), level=3)
            last_was_major_heading = False
            current_list_type = None
        elif line_stripped.startswith('#### '):
            heading = doc.add_heading(line_stripped[5:].strip(), level=4)
            last_was_major_heading = False
            current_list_type = None
        elif line_stripped.startswith('##### '):
            heading = doc.add_heading(line_stripped[6:].strip(), level=5)
            last_was_major_heading = False
            current_list_type = None
        # Handle bold-only lines (metadata)
        elif line_stripped.startswith('**') and line_stripped.endswith('**'):
            para = doc.add_paragraph()
            add_formatted_text(para, line_stripped)
            last_was_major_heading = False
            current_list_type = None
        # Handle numbered lists
        elif re.match(r'^\d+\.\s', line_stripped):
            text = re.sub(r'^\d+\.\s+', '', line_stripped)
            text = clean_markdown_text(text)
            para = doc.add_paragraph(text, style='List Number')
            last_was_major_heading = False
            current_list_type = 'numbered'
        # Handle bullet lists
        elif line_stripped.startswith('- ') or line_stripped.startswith('* '):
            text = line_stripped[2:].strip()
            text = clean_markdown_text(text)
            para = doc.add_paragraph(text, style='List Bullet')
            last_was_major_heading = False
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
                last_was_major_heading = False
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
        print("\nNote: Please update the front page with your name, student ID, and date.")
    except FileNotFoundError:
        print("Error: Academic_Report.md not found!")
    except ImportError:
        print("Error: python-docx library not installed!")
        print("Please install it using: pip install python-docx")
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()

