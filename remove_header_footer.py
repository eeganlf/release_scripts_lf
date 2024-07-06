
import fitz  # PyMuPDF
import sys

def remove_header_footer(input_pdf_path, output_pdf_path, header_height=50, footer_height=50):
    # Open the PDF
    pdf_document = fitz.open(input_pdf_path)
    page_count = pdf_document.page_count
    
    # Process each page
    for page_num in range(page_count):
        page = pdf_document.load_page(page_num)
        rect = page.rect
        footer_rect = fitz.Rect(0, rect.height - footer_height, rect.width, rect.height)
        header_rect = fitz.Rect(0, 0, rect.width, header_height)
        page.add_redact_annot(footer_rect, fill=(1, 1, 1))  # white fill for the redaction
        page.add_redact_annot(header_rect, fill=(1, 1, 1))  # white fill for the redaction
        page.apply_redactions()

    # Save the modified PDF
    pdf_document.save(output_pdf_path)
    pdf_document.close()

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python script.py <input_pdf_path> <output_pdf_path>")
        sys.exit(1)
    
    input_pdf_path = sys.argv[1]
    output_pdf_path = sys.argv[2]

    remove_header_footer(input_pdf_path, output_pdf_path)

