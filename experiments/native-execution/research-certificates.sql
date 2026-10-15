SELECT id,title,doi_norm,publication_year,cited_by_count
FROM openalex.works
WHERE hasAllTokens(search_text_lc,['verified','certificate','checker'])
   OR hasAllTokens(search_text_lc,['verified','database','query'])
   OR hasAllTokens(search_text_lc,['proof','reflection','isabelle'])
ORDER BY cited_by_count DESC
LIMIT 60
