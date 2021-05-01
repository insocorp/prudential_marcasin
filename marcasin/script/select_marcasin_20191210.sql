--
-- select_marcasin_20191210.sql
--

SELECT 
   '',
   pasta_seguro.NR_CONTROLE,
   pasta_seguro.NR_SINISTRO,
   pasta.NR_PASTA,
   pasta.DT_CITACAO,
   pasta_pfpj_parte_contraria.CIP,
   pasta_pfpj_parte_contraria.PFPJ,
   pfpj_parte_contraria.CNPJ_CPF,
   pasta.UF,
   exito_riscoperda.RISCOPERDA,
   pasta.VL_CAUSA,
   pasta.VL_CAUSA,
   0.00,
   pasta.NR_PROCESSO,
   pasta_pfpj_reclamante.PFPJ,
   pasta_seguro.OBJETO_SINISTRO,
   pasta_seguro.CD_RAMOSRSN,
   pasta_seguro.NR_SINISTRO_FENASEG,
   0,
   0,
   0,
   0 
FROM pasta 
LEFT JOIN exito_riscoperda 
  ON pasta.PC_RISCO = exito_riscoperda.PC_RISCO 
JOIN pasta_seguro 
  ON pasta.NR_PASTA = pasta_seguro.NR_PASTA 
LEFT JOIN pasta_pfpj_parte_contraria 
  ON pasta.NR_PASTA = pasta_pfpj_parte_contraria.NR_PASTA 
LEFT JOIN pasta_pfpj_reclamante 
  ON pasta.NR_PASTA = pasta_pfpj_reclamante.NR_PASTA 
LEFT JOIN pfpj pfpj_parte_contraria 
  ON pasta_pfpj_parte_contraria.CIP = pfpj_parte_contraria.CIP 
WHERE pasta.TP_PASTA IN ('Cível com Sinistro VG','Migração') 
  AND pasta_seguro.NR_CONTROLE > 0 
  AND COALESCE(pasta_seguro.NR_SINISTRO,'') <> '' 
ORDER BY 
   pasta.NR_PASTA,
   pasta_seguro.NR_CONTROLE
;
