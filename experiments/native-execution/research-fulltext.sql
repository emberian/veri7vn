SELECT paper_key,quality_label,converter,text
FROM academic.papers
WHERE paper_key IN ('10.1145/1708046.1708058',
 '10.4230/lipics.itp.2019.22',
 '10.1007/s10817-019-09525-z',
 '10.1007/s10817-017-9437-1',
 '10.1145/2854065.2854067',
 '10.48550/arxiv.1707.02115',
 '10.4230/lipics.itp.2024.22')
AND quality_label = 'good'
LIMIT 10
