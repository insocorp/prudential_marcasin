--
-- select_match_20200323.sql
--

\o ../file/lista_match_20200323.csv

SELECT
   pasta_seguro.NR_SINISTRO AS  NR_SINISTRO                 ,
   pasta.NR_PASTA AS NR_PASTA                               ,
   pasta.DT_CITACAO AS DT_CITACAO                           ,
   pasta_pfpj_parte_contraria.CIP AS ID_PESSOA_AUTOR        ,
   pfpj_parte_contraria.PFPJ AS NM_AUTOR                    ,
   pfpj_parte_contraria.CNPJ_CPF AS NR_CNPJ_CPF_AUTOR       ,
   pasta.UF AS CD_UF                                        ,
   exito_riscoperda.RISCOPERDA AS NM_PERDA                  ,
   pasta.VL_CAUSA AS VL_ECONOMICO                           ,
   pasta.VL_CAUSA AS VL_ACAO                                ,
   pasta.NR_PROCESSO AS NR_PROCESSO_JUDICIAL                ,
   pasta_pfpj_reclamante.PFPJ AS NM_RECLAMANTE              ,
   pasta_seguro.OBJETO_SINISTRO AS ID_MOTIVO_JUDICIAL       ,
   pasta_seguro.CD_RAMOSRSN AS NR_RAMO                      ,
   pasta_seguro.NR_SINISTRO_FENASEG AS ID_PRODUTO_COBERTURA ,   
   pedido.VL_ATUALIZADO AS VL_ATUALIZADO_TOTAL              , 
   pedido.VL_RISCO_CALC AS VL_RISCO_CALC                    , 
   pedido.VL_CORRECAO AS VL_CORRECAO                        , 
   pedido.VL_JUROS AS VL_JUROS                               
FROM pasta_seguro
JOIN pasta
  ON pasta_seguro.NR_PASTA = pasta.NR_PASTA
LEFT JOIN exito_riscoperda
  ON pasta.PC_RISCO = exito_riscoperda.PC_RISCO
LEFT JOIN pasta_pfpj_parte_contraria
  ON pasta.NR_PASTA = pasta_pfpj_parte_contraria.NR_PASTA
LEFT JOIN pasta_pfpj_reclamante
  ON pasta.NR_PASTA = pasta_pfpj_reclamante.NR_PASTA
LEFT JOIN pfpj pfpj_parte_contraria
  ON pasta_pfpj_parte_contraria.CIP = pfpj_parte_contraria.CIP
LEFT JOIN (
  SELECT
     pasta_pedidos.NR_PASTA AS NR_PASTA ,
     pasta_pedidos.NR_CONTROLE_SEGURO AS NR_CONTROLE ,
     SUM(COALESCE(pasta_pedidos.VL_RISCO_CALC,0.00)) AS VL_RISCO_CALC ,
     SUM(COALESCE(pasta_pedidos.VL_CORRECAO,0.00)) AS VL_CORRECAO ,
     SUM(COALESCE(pasta_pedidos.VL_JUROS,0.00)) AS VL_JUROS ,
     SUM(COALESCE(pasta_pedidos.VL_RISCO_CALC,0.00) + 
        COALESCE(pasta_pedidos.VL_CORRECAO,0.00) +
        COALESCE(pasta_pedidos.VL_JUROS,0.00)) AS VL_ATUALIZADO 
  FROM pasta_seguro
  JOIN pasta_pedidos
    ON pasta_seguro.NR_PASTA = pasta_pedidos.NR_PASTA
   AND pasta_seguro.NR_CONTROLE = pasta_pedidos.NR_CONTROLE_SEGURO
  WHERE COALESCE(pasta_seguro.NR_SINISTRO,'') <> ''
    AND pasta_pedidos.NR_CONTROLE_SEGURO > 0
  GROUP BY  
     pasta_pedidos.NR_PASTA  ,
     pasta_pedidos.NR_CONTROLE_SEGURO  
  ) pedido
   ON pasta_seguro.NR_PASTA = pedido.NR_PASTA
  AND pasta_seguro.NR_CONTROLE = pedido.NR_CONTROLE
ORDER BY
   pasta_seguro.NR_SINISTRO ,
   pasta.NR_PASTA 
;

\o
    
       