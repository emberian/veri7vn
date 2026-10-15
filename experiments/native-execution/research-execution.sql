SELECT id,title,doi_norm,publication_year,cited_by_count
FROM openalex.works
WHERE hasAllTokens(search_text_lc,['isabelle','code','generation'])
   OR hasAllTokens(search_text_lc,['isabelle','llvm'])
   OR hasAllTokens(search_text_lc,['isabelle','parallel'])
ORDER BY cited_by_count DESC
LIMIT 60
