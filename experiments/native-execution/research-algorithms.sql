SELECT id,title,doi_norm,publication_year,cited_by_count
FROM openalex.works
WHERE hasAllTokens(search_text_lc,['verified','sat'])
   OR hasAllTokens(search_text_lc,['refinement','imperative'])
   OR hasAllTokens(search_text_lc,['verified','query'])
   OR hasAllTokens(search_text_lc,['certificate','reflection'])
ORDER BY cited_by_count DESC
LIMIT 60
