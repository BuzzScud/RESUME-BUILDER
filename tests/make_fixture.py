from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
p=Path(__file__).parent
image=Image.new('RGB',(1300,1500),'#ffffff');draw=ImageDraw.Draw(image)
font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',32)
bold=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Bold.ttf',42)
draw.text((75,70),'EXAMPLE EMPLOYER',font=bold,fill='#23372f')
draw.text((75,155),'Python Software Developer',font=bold,fill='#23372f')
lines=['Job posting - synthetic test fixture','','Build Python APIs and SQL data pipelines.','Work with PostgreSQL, FastAPI, and automated tests.','Develop retrieval systems and document search.','Collaborate with customers and explain technical workflows.','','Required qualifications:','Hands-on Python and SQL development.','Experience shipping tested software.','Clear written and verbal communication.','','Preferred qualifications:','A PhD in Computer Science.','12 years of Kubernetes administration.','','Apply with a resume and cover letter.']
y=265
for line in lines:draw.text((75,y),line,font=font,fill='#37463f');y+=57
image.save(p/'job-posting.png')
