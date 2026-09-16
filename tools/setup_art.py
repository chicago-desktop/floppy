"""Export the module's original, integer-grid SVG illustration (requires Pillow)."""
from pathlib import Path
import re
import xml.etree.ElementTree as ET
from PIL import Image, ImageDraw
root = Path(__file__).resolve().parent.parent / 'assets/images'
image = Image.new('RGB', (120, 224), '#55a6a8')
draw = ImageDraw.Draw(image)
for element in ET.parse(root / 'setup.svg').iter():
    if not element.tag.endswith('path'):
        continue
    numbers = [int(n) for n in re.findall(r'-?\d+', element.attrib['d'])]
    points = list(zip(numbers[::2], numbers[1::2]))
    draw.polygon(points, fill=element.attrib['fill'])
    if element.attrib.get('stroke') != 'none':
        draw.line(points + [points[0]], fill='#404040', width=1)
image.save(root / 'pictures/setup.png')
