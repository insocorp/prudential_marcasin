/*
* Program..: proc_sinistro.prg
* Objective: processar o envio e retorno de dados de sinistros
* Comments.: conhecido como MATCH / MARCASIN
*/
          
# define NEWLINE chr(10)
# define EOF chr(26)

function main(fcType , fcSinistro)
   local llFlg      := .T.  // as logical
   local lnHOcor    := 0,;
         lnHand1    := 0,;
         lnHand2    := 0,;
         lnFile     := 0,;
         lnHPFile   := 0,;
         lnHDespFile:= 0,;
         ii         := 0,;
         xx         := 0 // as int
   local ldDtTermino:= ctod("  /  /    "),;
         ldDtNula   := ctod("  /  /    "),;
         ldDtInicio := ctod("  /  /    ") // as date 
   local lcParam    := "wpbatch.ini",;
         lcVersao   := "Versao: carga_sinistro_i4pro_10/12/2019 - 15:28",; // deve-se alterar a data a cada envio
         lcOBJ1     := "",; // handle para a conexao com banco origem
         lcOBJ2     := "",; // handle para a conexao com banco destino
         lcTabSeqInt:= "seq_interfaces",;
         lcProgram  := "Proc_Sinistro_Coweb",;
         lcFileDbf  := "*.dbf",;
         lcFileDbt  := "*.dbt",;
         lcFileSql  := "*.sql",;
         lcFileLog  := "*.log",;
         lcPagNetInp:= "",; // TAG PAGNETINPUT
         lcPagNetOut:= "",; // TAG PAGNETOUTPUT
         lcHrInicio := "",;
         lcErrorFile:= "",;
         lcHrTermino:= "",;
         lcPath     := "",;
         lcPOutI4Pro:= "",;
         lcPInpI4Pro:= "",;
         lcFOutI4Pro:= "",;
         lcFInpI4Pro:= "",;
         lcHrNula   := "",;
         lcVal      := "",;
         lcStatus   := "",;
         lcPatFil   := "",;
         lcFile     := "",;
         lcLogFil   := "",;
         lcMess     := "" // as string
   local laCabLog   := {space(10) + "Ocorrencias de processamento de Envio e Retorno de Dados do Sinistro Coweb - ISJ",;
                        "Data: ",;
                        lcVersao,;
                        ""},;
         laResumo   := {},;
         laFiles    := {},;
         laSeqInt   := {},;
         laTemp     := {} // as array

   set date to british
   set century on
   set scoreboard off

   public plFlg      := .T.
   public plTstLctoCt:= .F. // ativar somente para fazer os testes de lançamento no mvt_contabil
   public pnErrorLog := 0
   public pnHOcor    := 0
   public pnErrorLog := 0
   public pnConAnali := 0
   public pnCurSet   := 1
   public pnSeqFile  := 0
   public pnSeqNumber:= 0
   public pnHand1
   public pcLogin    := "carga_i4pro"
   public pcLgPadrao := "carga_i4pro"
   public pcProgram  := lcProgram
   public pcSysError := ""
   public pcSinistro := ""
   public pdDtInicio := date() 
   public pcHrInicio := time()
   public pdDtTermino:= date() 
   public pcHrTermino:= time()
   public paExporta  := {}
   
   if ! empty(fcType)
      fcType:= upper(alltrim(fcType))
   else
      fcType:= ""
   endif
   if fcType <> "ENVIO"   .and.;
      fcType <> "RETORNO"
      ? "Informe o tipo de processamento: ENVIO ou RETORNO"
      quit
   endif   
   
   if ! empty(fcSinistro)
      pcSinistro:= alltrim(fcSinistro)
   endif
   
   lcPOutI4Pro:= getParametersTag("PATHOUTI4PRO",lcParam)  // diretorio para a saida de arquivos (exportacao)
   lcFOutI4Pro:= getParametersTag("FILEOUTI4PRO",lcParam)  // prefixo dos arquivos de exportacao
   lcPInpI4Pro:= getParametersTag("PATHINPI4PRO",lcParam)  // diretorio para a entrada de arquivos (importacao)
   lcFInpI4Pro:= getParametersTag("FILEINPI4PRO",lcParam)  // prefixo dos arquivos de importaçao
   if empty(lcPOutI4Pro)
      ? "??? Diretorio de saida dos arquivos nao informado no arquivo de parametros"
      llFlg := .F.
   endif
   if empty(lcFOutI4Pro)
      ? "??? Prefixo dos arquivos de saida nao informado no arquivo de parametros"
      llFlg := .F.
   endif
   if empty(lcPInpI4Pro)
      ? "??? Diretorio de entrada dos arquivos nao informado no arquivo de parametros"
      llFlg := .F.
   endif
   if empty(lcFInpI4Pro)
      ? "??? Prefixo dos arquivos de entrada nao informado no arquivo de parametros"
      llFlg := .F.
   endif
   if ! llFlg
      quit
   endif   
   if llFlg
      lcPath:= getParametersTag("PATHLOG",lcParam)
      lcErrorFile:= lcPath + "SystemErrorsLog" + dtos(date()) + "_" + strtran(time(),":","") + ".log"
      pnErrorLog:= fcreate(lcPath + lcErrorFile,0)
   endif  
   writeLine(pnErrorLog,"Data de processamento: " + dtoc(date()) + " - Hora: " + time())
   ? "Preparando o ambiente - Aguarde..."   
   if llFlg
      if ! printParamsInfoNew(pnCurSet,0,lcParam,pnErrorLog)
         lcMess:= "??? Problemas na gravaçao de dados do arquivo de parametros: " + lcParam
         llFlg := .F.
      endif
   endif
   if llFlg
      laCabLog[2]+= dtoc(date()) + " - Hora: " + time()
      * funcao obrigatoria no inicio do programa
      wicCreateVars()
      * setando o banco ativo
      pnCurSet:= 1
      * processando a conexao com o banco de dados
      poSql1:= wicDBConnect(pnCurSet,@pnHand1,lcParam) //  ip 192.168.0.4
      if pnHand1 < 1
         lcMess:= "??? Problemas na conexao com o banco origem"
         llFlg := .F.   
      endif
   endif
   if llFlg
      ? "Conexao processada com sucesso"
      * criando um arquivo para log de ocorrencias
      lcPath  := alltrim(wicGetSetEnvs(pnCurSet,"PATHLOG"))
      lcFile  := alltrim(wicGetSetEnvs(pnCurSet,"LOGFILE")) + "carga_i4pro_isj_" + strzero(year(date()),4) + strzero(month(date()),2) + strzero(day(date()),2) + ".log"
      lcFile  := lcPath + lcFile
      lcLogFil:= lcFile
      lnHOcor := createLogFile(lcFILE,laCabLog)

      if lnHOcor > 0
         pnHOcor:= lnHOcor
      else     
         lcMess := "??? Problemas na criaçao do arquivo: " + lcFile
         llFlg  := .F.
      endif
   endif
   if llFlg
      pdDtInicio:= date() 
      pcHrInicio:= time()
      lcMess:= "Data Inicio: " + dtoc(pdDtInicio) + " - Hora: " + pcHrInicio
      dispMessage(lnHOcor,lcMess)
      dispMessage(lnHOcor,"")   
   endif   
   if llFlg
      db_init(pnHand1)
      if ! inicializaSeqInterfaces(lcProgram,0,pdDtInicio,pcHrInicio,ldDtNula,lcHrNula,"I",ldDtNula,ldDtNula,"S",ldDtNula)
         lcMess:= "??? Problemas na gravaçao de inicio na tabela: seq_interfaces"
         llFlg := .F.
         db_rollback(pnHand1)
      else
         db_commit(pnHand1)
      endif
   endif
   if llFlg
      if ! printParamsInfoNew(pnCurSet,0,lcParam,pnHOcor)
         lcMess:= "??? Problemas na gravçao de dados do arquivo de parametros: " + lcParam
         llFlg := .F.
      endif
   endif
   if llFlg
      db_init(pnHand1)
   endif

   if llFlg
      if fcType == "ENVIO"
         if ! excluirArquivosXml(lcPOutI4Pro,lcFOutI4Pro)
            lcMess:= "??? Problemas na exclusao de arquivos xlm de envio"
            llFlg := .F.
         endif
      endif
   endif   
   if llFlg
      if fcType == "ENVIO"
         if ! procEnvioSinistro(lcPOutI4Pro,lcFOutI4Pro,pcSinistro)
            lcMess:= "??? Problemas no envio de dados de Sinistro para o I4Pro"
            llFlg := .F.
         endif   
      endif
   endif
   if llFlg
      if fcType == "RETORNO"

         if ! procRetornoSinistro(lcPInpI4Pro,lcFInpI4Pro)
            lcMess:= "??? Problemas no retorno de dados de Sinistro do I4Pro"
            llFlg := .F.
         endif
      endif
   endif

   if llFlg
      db_init(pnHand1)
   endif    

   if llFlg
      if fcType == "ENVIO"
         lcMess:= "Envio de dados de Sinistro para o I4Pro processado com SUCESSO"
      else
         lcMess:= "Retorno de dados de Sinistro do I4Pro processado com SUCESSO"
      endif
      dispMessage(lnHOcor,lcMess)
   endif

   dispMessage(lnHOcor,"")
   pdDtTermino:= date()
   pcHrTermino:= time()                                                                                          
   lcMess:= "Data Termino: " + dtoc(pdDtTermino) + " - Hora: " + pcHrTermino
   dispMessage(lnHOcor,lcMess)
   * calculando o tempo de processamento
   lcTempoProc:= calcIntervaloTempoNovo(pdDtInicio,pcHrInicio,pdDtTermino,pcHrTermino)   
   lcMess:= "Tempo de processamento: " + lcTempoProc
   dispMessage(lnHOcor,lcMess)

   if lnHOcor > 0
      fclose(lnHOcor)
   endif
   if pnErrorLog > 0
      fclose(pnErrorLog)
   endif
   if llFlg
      lcStatus:= "T"
   else
      lcStatus:= "E"
   endif
   *                                  1    2    3           4          5           6           7        8       9      10    11    12         13
   if ! finalizandoSeqInterfaces(lcProgram,0,pdDtInicio,pcHrInicio,pdDtTermino,pcHrTermino,lcStatus,ldDtNula,ldDtNula,"S",date(),lcLogFil,lcErrorFile)   
      lcMess:= "??? Problemas na atualizaçao da tabela: seq_interfaces"
      llFlg := .F.
   endif
   if llFlg
      db_commit(pnHand1)
   else
      db_rollback(pnHand1)
   endif
   if pnHand1 > 0
      * desconectando com o banco
      wicDBDisconnect(1,pnHand1)
   endif 
   if llFlg
      run("rm " + lcErrorFile)   
   endif
   * RUN("DEL " + lcFileLog)
   ? ""
   if lnHDespFile > 0
      fclose(lnHDespFile)
   endif

return (nil)
/*
* Function..: procEnvioSinistro()
* Objective.: processar o envio de dados para o I4Pro
* Parameters:
*   fcPath..: diretorio para a criaçao dos arquivos xml
*   fcFile..: prefixo dos arquivos xml
*   fcSini..: sinistro
*             se for informado, processa somente esse sinistro
* Return....: .t./.f.
*   .t. processado com sucesso
*   .f. problemas no processamento
* Comments..:
* Email do Glauber com os esclarecimentos
* Segue
* O arquivo a ser gerado vai ser um xml ?
* R: exato
* Se for, qual é o prefixo do arquivo para eu gerar, pois entendo que para cada NR_PASTA + NR_SINISTRO, será gerado um arquivo XML
* R:  Pelo que entendi será um único arquivo com várias linhas onde cada linha corresponde a um sinistro, então acredito o nome do arquivo pode ser formado assim MARCARSIN_YYYYMMDD_HHMMSS.XML.
* Para cada linha deste arquivo a informação deve seguir leiaute abaixo:
* <i4proerp><MarcarSinistroJudicial nr_sinistro ="90193194863101" nr_pasta ="84943" dt_citacao ="15-05-2018" id_pessoa_autor ="21414" nm_autor ="LUIS FERNANDO ALVES LOPES DOS SANTOS" nr_cnpj_cpf_autor "21256666858" cd_uf ="" nm_perda ="REMOTA" vl_economico ="50000.00" vl_acao ="50000.00" vl_pagamento ="0.00" nr_processo_judicial ="028262553" motivo_judicial ="" vl_atualizado_total = “150000.00”/> </i4proerp>
* A quebra de linha (chr(13)) deve ser inserida após a tag  </i4proerp> .
* Apesar de estar escrito no layout que não será informado, preciso ter certeza para evitar alterações e último hora que tenho que fazer na hora e pode ser que eu esteja numa consulta médica e não tenha como fazer na hora
* VALOR DO PAGAMENTO, o que seria ? Você precisa me informar o nome da tabela e coluna do ISJ
* R: Informar conteúdo fixo 0.00
* NOME DO RECLAMANTE , qual a informação do ISJ ?
* R: Pegar o PFPJ com base na tabela pasta_cip, wfield = CIP_RECLAMANTE
* MOTIVO JUDICIAL , qual a informação do ISJ ?
* R: pasta_seguro.OBJETO_SINISTRO
* NÚMERO DO RAMO", qual a informação do ISJ ?
* R: pasta_seguro.CD_RAMO_SRSN
* ID_PRODUTO_COBERTURA", qual a informação do ISJ ? 
* R: pasta_seguro.NR_SINISTRO_FENASEG
* NOME DA COBERTURA qual a informação do ISJ ?
* R: pasta_seguro_lmi.LMI_NM_COBERTURA
* Observação: Esta tabela tem relacionamento de 1..N com pasta_seguro, porém o Alexandre definiu com eles que seria 1 cobertura por sinistro, então neste caso pegar sempre o primeiro registro.
*/
function procEnvioSinistro(fcPath,fcFile,fcSini)
   local llFlg       := .T. // as logical
   local lnMaxRow    := 1000,;
         lnRefRow    := lnMaxRow,;
         lnRecoun    := 0,;
         lnCurRow    := 0,;
         lnError     := 0,;
         lnNrPasta   := 0,;
         lnNrContSeg := 0,;
         lnVlRisco   := 0,;
         lnVlReserva := 0,;
         lnVlRisCalc := 0,;
         lnVlCorrecao:= 0,;
         lnVlJuros   := 0,;
         lnXhmlFile  := 0,;
         ii          := 0,;
         nn          := 0   // as int
   local lxVal,;
         lxRet,;
         lbProc      
   local ldDtCitacao := ctod("  /  /    ") // as date      
   local lcTabPasta  := "pasta",;
         lcTabSeguro := "pasta_seguro",;
         lcTabSegLmi := "pasta_seguro_lmi",;
         lcTabPrt    := "pasta_pfpj_parte_contraria",;
         lcTabRec    := "pasta_pfpj_reclamante",;
         lcTabPfpj   := "pfpj",;
         lcTabPfpjPrt:= "pfpj_parte_contraria",;
         lcTabExito  := "exito_riscoperda",;
         lcNrSinistro:= "",;
         lcCnpjCpfPrt:= "",;
         lcUf        := "",;
         lcCipPrt    := "",;
         lcPfpjPrt   := "",;
         lcPfpjRec   := "",;
         lcRiscoPerda:= "",;
         lcNrProcesso:= "",;
         lcObjSinist := "",;
         lcRamoSrSn  := "",;
         lcFenaSeg   := "",;
         lcNmCobert  := "",;
         lcColumn    := "",;
         lcJoin      := "",;
         lcFile      := "",;
         lcMess      := ""  // as string
   local laTables    := {},;
         laCols      := {},;
         laVals      := {},;
         laJoin      := {},;
         laOrder     := {},;
         laWhere     := {},;
         laResult    := {}  // as array
  
   public pnSeqI4Pro := 0
   
   *                1     2        3                    4                 5                         6                     7   8  9    10        11                       12
   aadd(laTables,{.F.   ,"SEQ","CAMPO"               ,"TIPO"         ,"DESCRIÇÃO"                  ,""                  ,"X",  0,0,""          ,"''"                 })                                                    //  1
   aadd(laTables,{.F.   ,00   ,"NR_CONTROLE_SEGURO"  ,"BIGINT"       ,"NÚMERO DE CONTROLE"         ,""                  ,"N", 20,0,lcTabSeguro ,"NR_CONTROLE"        ,{|| getVariavel(lxVal,@lxRet,@lnNrContSeg)}})        //  2  pasta_seguro.NR_SINISTRO
   aadd(laTables,{.T.   ,01   ,"NR_SINISTRO"         ,"BIGINT"       ,"NÚMERO DO SINISTRO"         ,""                  ,"N", 20,0,lcTabSeguro ,"NR_SINISTRO"        ,{|| getSomenteNumeros(lxVal,@lxRet,@lcNrSinistro)}}) //  3  pasta_seguro.NR_SINISTRO
   aadd(laTables,{.T.   ,02   ,"NR_PASTA"            ,"VARCHAR(15)"  ,"NÚMERO DA PASTA JUDICIAL"   ,""                  ,"C", 15,0,lcTabPasta  ,"NR_PASTA"           ,{|| getVariavel(lxVal,@lxRet,@lnNrPasta)}})          //  4  pasta.NR_PASTA
   aadd(laTables,{.T.   ,03   ,"DT_CITACAO"          ,"VARCHAR(10)"  ,"DATA DA CITAÇÃO"            ,"(DD-MM-AAAA)"      ,"D",  8,0,lcTabPasta  ,"DT_CITACAO"         ,{|| getVariavel(lxVal,@lxRet,ldDtCitacao)}})         //  5  pasta.DT_CITACAO
   aadd(laTables,{.T.   ,04   ,"ID_PESSOA_AUTOR"     ,"INT"          ,"CÓDIGO DO AUTOR"            ,""                  ,"N", 20,0,lcTabPrt    ,"CIP"                ,{|| getVariavel(lxVal,@lxRet,@lcCipPrt)}})           //  6  CIP_PARTE_CONTRARIA
   aadd(laTables,{.T.   ,05   ,"NM_AUTOR"            ,"VARCHAR(100)" ,"NOME DO AUTOR"              ,""                  ,"C",100,0,lcTabPrt    ,"PFPJ"               ,{|| getVariavel(lxVal,@lxRet,lcPfpjPrt)}})           //  7  pasta_pfpj_parte_contraria.PFPJ
   aadd(laTables,{.T.   ,06   ,"NR_CNPJ_CPF_AUTOR"   ,"BIGINT"       ,"CPF OU CNPJ DO AUTOR"       ,""                  ,"N", 20,0,lcTabPfpjPrt,"CNPJ_CPF"           ,{|| getSomenteNumeros(lxVal,@lxRet,@lcCnpjCpfPrt)}}) //  8  CNPJ_CPF da parte contrária
   aadd(laTables,{.T.   ,07   ,"CD_UF"               ,"VARCHAR(2)"   ,"UF"                         ,"NÃO SERÁ INFORMADO","C",  2,0,lcTabPasta  ,"UF"                 ,{|| getPastaUf(lxVal,@lxRet,@lcUf)}})                //  9  pasta.UF com space(2)
   aadd(laTables,{.T.   ,08   ,"NM_PERDA"            ,"VARCHAR(30)"  ,"TIPO DE PERDA"              ,""                  ,"C", 30,0,lcTabExito  ,"RISCOPERDA"         ,{|| getRiscoPerda(lxVal,@lxRet,@lcRiscoPerda)}})     // 10  pasta.PC_RISCO exito_riscoperda.NM_
   aadd(laTables,{.T.   ,09   ,"VL_ECONOMICO"        ,"NUMERIC"      ,"VALOR ECONÔMICO DO PROCESSO",""                  ,"N", 20,0,lcTabPasta  ,"VL_CAUSA"           ,{|| getVariavel(lxVal,@lxRet,@lnVlRisco)}})          // 11  pasta.VL_ACAO
   aadd(laTables,{.T.   ,10   ,"VL_ACAO"             ,"NUMERIC"      ,"VALOR DA AÇÃO"              ,""                  ,"N", 20,2,lcTabPasta  ,"VL_CAUSA"           ,{|| getValorVariavel(lxVal,@lxRet,lnVlRisco)}})      // 12  pasta.VL_ACAO
   aadd(laTables,{.T.   ,11   ,"VL_PAGAMENTO"        ,"NUMERIC"      ,"VALOR DO PAGAMENTO"         ,""                  ,"N", 20,2,""          ,"0.00"               ,{|| getValorVariavel(lxVal,@lxRet,0.00)}})           // 13  a ser informado
   aadd(laTables,{.T.   ,12   ,"NR_PROCESSO_JUDICIAL","VARCHAR(20)"  ,"NÚMERO DO PROCESSO JUDICIAL",""                  ,"N", 20,0,lcTabPasta  ,"NR_PROCESSO"        ,{|| getVariavel(lxVal,@lxRet,@lcNrProcesso)}})       // 14  pasta.NR_PROCESSO
   aadd(laTables,{.T.   ,13   ,"NM_RECLAMANTE"       ,"VARCHAR(100)" ,"NOME DO RECLAMANTE"         ,"NÃO SERÁ INFORMADO","C",100,0,lcTabRec    ,"PFPJ"               ,{|| getVariavel(lxVal,@lxRet,@lcPfpjRec)}})          // 15  a ser informado
   aadd(laTables,{.T.   ,14   ,"ID_MOTIVO_JUDICIAL"  ,"INT"          ,"MOTIVO JUDICIAL"            ,""                  ,"N", 20,0,lcTabSeguro ,"OBJETO_SINISTRO"    ,{|| getValorVariavel(lxVal,@lxRet,"601")}})          // 16  a ser informado
   aadd(laTables,{.T.   ,15   ,"NR_RAMO"             ,"INT"          ,"NÚMERO DO RAMO"             ,"NÃO SERÁ INFORMADO","N", 20,0,lcTabSeguro ,"CD_RAMOSRSN"        ,{|| getVariavel(lxVal,@lxRet,@lcRamoSrSn)}})         // 17  a ser informado
   aadd(laTables,{.T.   ,16   ,"ID_PRODUTO_COBERTURA","INT"          ,"CÓDIGO DA COBERTURA"        ,"NÃO SERÁ INFORMADO","N", 20,0,lcTabSeguro ,"NR_SINISTRO_FENASEG",{|| getVariavel(lxVal,@lxRet,@lcFenaseg)}})          // 18  a ser informado   
   * aadd(laTables,{.T.   ,17   ,"NM_COBERTURA"        ,"VARCHAR(100)" ,"NOME DA COBERTURA"          ,"NÃO SERÁ INFORMADO","C",100,0,lcTabSegLmi ,"LMI_NM_COBERTURA"   ,{|| getValorVariavel(lxVal,@lxRet,@lcNmCobert)}})  // 19  a ser informado
   aadd(laTables,{.T.   ,18   ,"VL_ATUALIZADO_TOTAL" ,"NUMERIC"      ,"VALOR DA RESERVA"           ,"NOVO ATRIBUTO"     ,"N", 20,2,""          ,"0"                  ,{|| getValorReserva(lxVal,@lxRet,@lnVlReserva,lnNrPasta,lnNrContSeg,@lnVlRisCalc,@lnVlCorrecao,@lnVlJuros)}}) // 20  pasta_pedidos somatória VL_RISCO_CALC, VL_CORRECAO + VL_JUROS 
   aadd(laTables,{.T.   ,19   ,"VL_RISCO_CALC"       ,"NUMERIC"      ,"VALOR DO RISCO CALCULADO"   ,"NOVO ATRIBUTO"     ,"N", 20,2,""          ,"0"                  ,{|| getValorVariavel(lxVal,@lxRet,@lnVlRisCalc)}})   // 21  pasta_pedidos somatória VL_RISCO_CALC, VL_CORRECAO + VL_JUROS 
   aadd(laTables,{.T.   ,20   ,"VL_CORRECAO"         ,"NUMERIC"      ,"VALOR DA CORRECAO"          ,"NOVO ATRIBUTO"     ,"N", 20,2,""          ,"0"                  ,{|| getValorVariavel(lxVal,@lxRet,@lnVlCorrecao)}})  // 22  pasta_pedidos somatória VL_RISCO_CALC, VL_CORRECAO + VL_JUROS 
   aadd(laTables,{.T.   ,21   ,"VL_JUROS"            ,"NUMERIC"      ,"VALOR DOS JUROS"            ,"NOVO ATRIBUTO"     ,"N", 20,2,""          ,"0"                  ,{|| getValorVariavel(lxVal,@lxRet,@lnVlJuros)}})     // 23  pasta_pedidos somatória VL_RISCO_CALC, VL_CORRECAO + VL_JUROS 
   *                1     2        3                    4                 5                         6                     7   8  9    10        11                12
                              
   for ii:= 1 to len(laTables)
   
      lcColumn:= ""
      if ! empty(laTables[ii,10])
         lcColumn:= alltrim(laTables[ii,10])
      endif
      if ! empty(lcColumn)
         lcColumn+= "."
      endif
      lcColumn+= laTables[ii,11]
      
      aadd(laCols,lcColumn)
      
   next ii

   * relacionamento da pasta com exito_riscoperda
   aadd(laJoin,{2,lcTabExito,lcTabPasta + ".PC_RISCO = " + lcTabExito + ".PC_RISCO"})   
   
   * relacionamento da pasta com pasta_seguro
   aadd(laJoin,{0,lcTabSeguro,lcTabPasta + ".NR_PASTA = " + lcTabSeguro + ".NR_PASTA"})

   * relacionamento da pasta com pasta_seguro_lmi
   * lcJoin:= lcTabSeguro + ".NR_PASTA = "    + lcTabSegLmi + ".NR_PASTA AND "
   * lcJoin+= lcTabSeguro + ".NR_CONTROLE = " + lcTabSegLmi + ".NR_CONTROLE"
   * aadd(laJoin,{2,lcTabSegLmi,lcJoin})

   * relacionamento da pasta com pasta_pfpj_parte_contraria
   aadd(laJoin,{2,lcTabPrt,lcTabPasta + ".NR_PASTA = " + lcTabPrt + ".NR_PASTA"})

   * relacionamento da pasta com pasta_pfpj_reclamante
   aadd(laJoin,{2,lcTabRec,lcTabPasta + ".NR_PASTA = " + lcTabRec + ".NR_PASTA"})

   * relacionamento da pasta_pfpj_parte_contraria com ppfpj
   aadd(laJoin,{2,lcTabPfpj + " " + lcTabPfpjPrt,lcTabPrt + ".CIP = " + lcTabPfpjPrt + ".CIP"})
   
   aadd(laOrder,lcTabPasta  + ".NR_PASTA")
   aadd(laOrder,lcTabSeguro + ".NR_CONTROLE")
   
   * setando as variaveis de ambiente                                                                                                             
   wicSetCurVars(pnCurSet)   
                                                                                                                                                     //     de pedidos com SINISTRO, por sinisto
   lcMess:= "Processando o Envio de Dados de Sinistro para o I4Pro"
   dispMessage(pnHOcor,lcMess)
   
   if ! empty(fcSini)
      lcMess:= space(3) + "Selecionando sinistro: " + fcSini
      dispMessage(pnHOcor,lcMess)
   endif

   lcFile:= fcPath + fcFile + dtos(date()) + strtran(time(),":","") + ".XML"
   lnHXmlFile := fcreate(lcFile,0)
   if lnHXmlFile > 0
   else
      lcMess:= space(3) + "??? Problemas na criação do arquivo: " + lcFile
      llFlg := .F.
   endif
   if llFlg
      aadd(laWhere,lcTabPasta  + ".TP_PASTA IN ('Cível com Sinistro VG','Migração')")
      aadd(laWhere,lcTabSeguro + ".NR_CONTROLE > 0")
      aadd(laWhere,"COALESCE(" + lcTabSeguro + ".NR_SINISTRO,'') <> ''")
      
      * condição incluida em 20/08/2019 conforme solicitação do cliente (Raphael/Celia)
      if ! empty(fcSini)
         aadd(laWhere,lcTabSeguro + ".NR_SINISTRO = '" + alltrim(fcSini) + "'")
      endif
      *                     1        2        3      4        5    6 7 8 9  10   11
      lnError:= db_select(laCols,lcTabPasta,laJoin,laWhere,laOrder, , , , ,.T.,pnHOcor)
      if lnError == -1
         lcMess:= space(3) + "??? Problemas na pesquisa na tabela: " + lcTabPasta
         llFlg := .F.
      else
         laResult:= db_fetchall()   
         lnRecoun:= len(laResult) -1
      endif
   endif
   if llFlg

      for ii:= 2 to len(laResult)

         dispProcess(@lnCurRow,@lnRefRow,lnMaxRow,lnRecoun,pnHOcor,.f.,.f.)      
         laVals:= {}

         for nn:= 1 to len(laTables)

            lxVal:= laResult[ii,nn]

            if len(laTables[nn]) > 11
               if valtype(laTables[nn,12]) == "B"
                  lbProc:= laTables[nn,12]
                  eval(lbProc)
                  lxVal:= lxRet
               endif
            endif
            aadd(laVals,lxVal)
            
         next nn

         if ! plFlg
            exit
         endif

         if ! geraEnvioXml(lnHXmlFile,laVals,laTables)
            lcMess:= space(3) + "??? Problemas na gravação no arquivo xml para envio"
            llFlg := .F.
            exit
         endif
         
      next ii

      if llFlg
         dispProcess(lnCurRow,lnRefRow,lnMaxRow,lnRecoun,pnHOcor,.t.,.f.)      
      endif
   endif
   
   if lnHXmlFile > 0
      fclose(lnHXmlFile)
   endif
   if ! llFlg
      dispMessage(pnHOcor,lcMess)
   endif
   plFlg:= llFlg
   
return (llFlg)
/*
* Function..: procRetornoSinistro()
* Objective.: processar o retorno de dados do I4Pro
* Parameters:
*   fcPath..: diretorio onde encontram-se os arquivos de entrada
*   fcFile..: prefixo dos arquivos de entrada
* Comments..:
   *  1 O exemplo abaixo corresponde a uma linha do arquivo de Saída (metadado XML – No arquivo não haverá as quebras de linha):
   *  2 <i4proerp>
   *  3 <SinistroJudicial 
   *  4 nr_sinistro="90193195808401" 
   *  5 dt_aviso="02/03/2018" 
   *  6 dt_ocorrencia="14/02/2017" 
   *  7 nm_status_sinistro="Re-aberto" 
   *  8 id_sin_pasta="37" 
   *  9 nr_pasta="84945" 
   * 10 nr_processo_judicial="0382625252" 
   * 11 nm_motivo_judicial="1 - Primeira estimativa" 
   * 12 dt_judicial="30/06/2017" 
   * 13 dt_citacao="30/06/2017" 
   * 14 nm_autor="DORIVAL PESSOA DA SILVA" 
   * 15 nr_cnpj_cpf_autor="39206586807" 
   * 16 nm_reclamante="" 
   * 17 nm_status_pasta="Pendente" 
   * 18 cd_uf="0" 
   * 19 nm_perda="Perda provável" 
   * 20 vl_economico="25000.00" 
   * 21 vl_acao="25000.00" 
   * 22 nm_segurado="DORIVAL PESSOA DA SILVA" 
   * 23 nr_cnpj_cpf_segurado="39206586807" 
   * 24 nm_sinistrado="DORIVAL PESSOA DA SILVA" nr_cnpj_cpf_sinistrado="39206586807" 
   * 25 cd_apolice="8681518" 
   * 26 nr_endosso="7" 
   * 27 cd_proposta="17352493" 
   * 28 nr_certificado="392065868" 
   * 29 dt_emissao_apolice="09/08/2016" 
   * 30 dt_emissao_endosso="07/02/2017" 
   * 31 dt_inicio_vigencia="01/01/2017" 
   * 32 dt_fim_vigencia="" 
   * 33 dt_inicio_vigencia_endosso="01/01/2017" dt_fim_vigencia_endosso="31/01/2017" 
   * 34 vl_premio="2836.12" 
   * 35 nm_estipulante="COR LINE SISTEMA DE SERVICOS LTDA" 
   * 36 nm_endereco_estipulante="RUA HONORIO AUGUSTO DE CAMARGO, 831" 
   * 37 nm_cep_cidade_uf_estipulante="06890000/SAO LOURENCO DA SERRA/SP" 
   * 38 nm_sub_estipulante="COR LINE SISTEMA DE SERVICOS LTDA" 
   * 39 nm_endereco_sub_estipulante="RUA HONORIO AUGUSTO DE CAMARGO, 831" 
   * 40 nm_cep_cidade_uf_sub_estipulante="06890000/SAO LOURENCO DA SERRA/SP" 
   * 41 nm_corretor="MARCEP CORRETAGEM DE SEGUROS S.A." 
   * 42 nm_causa="MORTE" 
   * 43 nm_motivo_causa="MORTE" 
   * 44 dt_demissao="" 
   * 45 dt_afastamento="" 
   * 46 id_followup="859999" 
   * 47 dt_followup="27/04/2018" 
   * 48 ds_followup="Usuário: alitomaData de Controle: 27/04/2018 14:03:00DOCUMENTOS COMPLEMENTARES RECEBIDOS 23/04/2018, ASSOCIADOS AO PROCESSO PARA CONTINUIDADE NA ANÁLISE // ALINE TOMASCZESKI //AR: PDF" 
   * 49 cd_retorno="00" 
   * 50 nm_retorno="Processamento efetuado com sucesso">
   * 51 <SinistroJudicialCoberturas 
   * 52 id_produto_cobertura="150" 
   * 53 nm_cobertura="MORTE" 
   * 54 nr_grp_ramo="9" 
   * 55 nr_ramo="93" 
   * 56 vl_aviso="14000.00" 
   * 57 vl_is="14000.00" 
   * 58 vl_reserva="0.01" 
   * 59 vl_pagamento="0.00" 
   * 60 nm_obs="" 
   * 61 nm_linha_digitavel="" 
   * 62 dt_cancelamento="" 
   * 63 id_tp_motivo_cancelamento="" motivo_cancelamento=""/>
   * 64 <SinistroJudicialBeneficiarios 
   * 65 id_pessoa_beneficiario="95762" 
   * 66 nm_beneficiario="DEOBALDO PESSOA DA SILVA" 
   * 67 nm_parentesco="Irmã(o)" 
   * 68 pc_participacao_segurado="100.00000"/>
   * 69 <SinistroJudicialCosseguro 
   * 70 dv_cosseguro="0" 
   * 71 cd_tp_cosseguro="" 
   * 72 nm_lider="" 
   * 73 id_pessoa_congenere="" 
   * 74 nm_congenere="" 
   * 75 pc_cosseguro="" 
   * 76 vl_is_cosseguro="" 
   * 77 vl_premio_cosseguro=""/>
   * 78 <SinistroJudicialResseguro 
   * 79 dv_resseguro="0" 
   * 70 id_pessoa_resseguradora="" 
   * 71 nm_resseguradora="" 
   * 72 pc_resseguro="" 
   * 73 vl_is_resseguro="" 
   * 74 vl_premio_resseguro=""/>
   * 75 </SinistroJudicial>
   * 76 </i4proerp>
       
   * Este arquivo de Saída deve ser gravado no mesmo local onde ocorreu a leitura do arquivo de Entrada, utilizado o mesmo nome de arquivo, porém, com a extensão “.RET”.
* Segue conforme solicitado.
*  1 TAG: nr_certificado
*    CAMPO ISJ: pasta_seguro.NR_CERTIFICADO
*  2 TAG: dt_emissao_apolice
*    CAMPO ISJ: pasta_seguro.DT_EMISSAO
*  3 TAG: vigencia_dt_inicio
*    CAMPO ISJ: pasta_seguro.DT_VIGENCIA_INI
*  4 TAG: dt_fim_vigencia
*    CAMPO ISJ: pasta_seguro.DT_VIGENCIA_FIN
*  5 TAG: vl_premio
*    CAMPO ISJ: pasta_seguro.VL_PREMIO
*  6 TAG: cd_tp_cosseguro
*    CAMPO ISJ: pasta_seguro.TP_COSSEGURO
*  7 TAG: pc_cosseguro
*    CAMPO ISJ: pasta_seguro.PC_COSSEGURO
*  8 TAG: nm_resseguradora
*   CAMPO ISJ: pasta_seguro.CIP_FILIAL_ATENDIMENTO
*  9 TAG: pc_resseguro
*    CAMPO ISJ: pasta_seguro.PC_RESSEGURO
* 10 TAG: vl_is_resseguro
*    CAMPO ISJ: pasta_seguro.VL_RESSEGURO
* 11 TAG: dt_emissao_endosso
*    CAMPO ISJ: pasta_seguro.DT_CONTRATACAO
* 12 TAG: endosso_dt_inicio_vigencia
*    CAMPO ISJ: pasta_seguro.DT_CANCELAMENTO
* 13 TAG: dt_fim_vigencia_endosso
*    CAMPO ISJ: pasta_seguro.DT_VLESTIMADO
* 14 TAG: pc_cosseguro
*    CAMPO ISJ: pasta_seguro.FL_COSSEGURO
*    OBSERVAÇÃO: SE pc_cosseguro não estiver vazio, alimentar FL_COSSEGURO com Y, caso contrário alimentar com N
* 15 TAG: pc_resseguro
*    CAMPO ISJ: pasta_seguro.FL_RESSEGURO
*    OBSERVAÇÃO: SE pc_resseguro não estiver vazio, alimentar FL_RESSEGURO com Y, caso contrário alimentar com N
* 16 TAG: id_sin_pasta
*    CAMPO ISJ: pasta_seguro.NR_SINISTRO_IRB
* 17 TAG: id_produto_cobertura
*    CAMPO ISJ: pasta_seguro.NR_SINISTRO_FENASEG
* Return....: .t./.f.
*  .t. processado com sucesso
*  .f. problemas no processamento
*/
function procRetornoSinistro(fcPath,fcFile)
   local llFlg       := .T.,;
         llEof       := .F.,;
         llGoOn      := .T. // as logical
   local lnBuffer    := 512,;
         lnMaxRow    := 100,;
         lnRefRow    := lnMaxRow,;
         lnCurRow    := 0,;
         lnRecoun    := 0,;
         lnError     := 0,;
         lnVlPremio  := 0,;
         lnPcCosseg  := 0,;
         lnPcResseg  := 0,;
         lnVlCosseg  := 0,;
         lnVlResseg  := 0,;
         lnNrPasta   := 0,;
         lnNrControle:= 0,;
         lnNrApolice := 0,;
         lnNrEndereco:= 0,;
         lnHFile     := 0,;
         lnCdCausaNis:= 0,;
         lnVlLmi     := 0,;
         lnVlAviso   := 0,;
         ii          := 0,;
         nn          := 0,;
         oo          := 0,;
         xx          := 0   // as int
   local lxVal,;
         lxRet,;
         lbProc      
   local ldDtEmissao := ctod("  /  /    "),;
         ldDtVigIni  := ctod("  /  /    "),;
         ldDtVigFin  := ctod("  /  /    "),;
         ldDtContra  := ctod("  /  /    "),;
         ldDtCandela := ctod("  /  /    "),;
         ldDtEstima  := ctod("  /  /    ") // as date     
   local lcTabPasta  := "pasta",;
         lcTabSeguro := "pasta_seguro",;
         lcTabSegSdo := "pasta_seguro_segurado",;
         lcTabSegVit := "pasta_seguro_vitima",;
         lcTabSegRecl:= "pasta_seguro_reclamante",;
         lcTabCausaNi:= "segurocausanis",;
         lcTabPfpj   := "pfpj",;
         lcBuffer    := space(lnBuffer),;
         lcLoginCada := "cargamatch",;
         lcTagErro   := "",;
         lcMensErro  := "",;
         lcCnpjCpfSeg:= "",;
         lcCnPjCpfVit:= "",;
         lcCipSeguro := "",;
         lcCipReclama:= "",;
         lcCipVitima := "",;
         lcCipFilAte := "",;
         lcCipEstip  := "",;
         lcCdCausaNi := "",;
         lcCipCorre  := "",;
         lcFile      := "",;
         lcLine      := "",;
         lcTagName   := "",;
         lcTagVal    := "",;
         lcNrSinistro:= "",;
         lcNrCertifi := "",;
         lcTpCosseg  := "",;
         lcFlCosseg  := "",;
         lcFlResseg  := "",;
         lcSiniIrb   := "",;
         lcSiniFena  := "",;
         lcNrProcesso:= "",;
         lcComando   := "",;
         lcEndereco  := "",;
         lcCep       := "",;
         lcCepSub    := "",;
         lcSubEstip  := "",;
         lcNmCobert  := "",;
         lcSinFenaseg:= "",;
         lcMess      := ""  // as string
   local laTables    := {},;
         laStruSeguro:= {},; // estrutura da tabela seguro para alteracao de dados
         laSCols     := {},; // colunas para select da tabela pasta_seguro
         laUCols     := {},; // colunas para alteraçao na tabela pasta_seguro
         laFiles     := {},;
         laFileVals  := {},;
         laProcs     := {},;
         laXml       := {},;
         laTagVals   := {},;
         laVals      := {},;
         laValues    := {},;
         laWhere     := {},;
         laResult    := {},;
         laResSeguro := {},;
         laValString := {},;
         laValCobert := {},;
         laValAviso  := {},;
         laValIs     := {},;
         laValSegLmi := {},;
         laTemp      := {}  // as array
   
   aadd(laSCols,"NR_PASTA")
   aadd(laSCols,"NR_CONTROLE")
   aadd(laSCols,"NR_SINISTRO")
   
   * tags a serem processadas                
   *              1  2       3                                4           5                        6     7 8 9             10 
   aadd(laProcs,{ 1,.F.,"nr_pasta"                        ,lcTabPasta  ,"NR_PASTA"                ,"N", 20,0,"",{|| getString2Numeric(lxVal,@lxRet,@lnNrPasta)                }})
   aadd(laProcs,{ 2,.F.,"nr_sinistro"                     ,lcTabSeguro ,"NR_SINISTRO"             ,"C", 20,0,"",{|| getVariavel(lxVal,@lxRet,@lcNrSinistro)                   }})
   aadd(laProcs,{ 3,.F.,"nr_processo_judicial"            ,lcTabPasta  ,"NR_PROCESSO" 	          ,"C", 35,0,"",{|| getVariavel(lxVal,@lxRet,@lcNrProcesso)                   }})
   aadd(laProcs,{ 4,.T.,"dt_aviso"                        ,lcTabSeguro ,"DT_AVISO" 	              ,"D",  8,0,"",{|| getString2Date(lxVal,@lxRet)                              }})
   aadd(laProcs,{ 5,.T.,"dt_ocorrencia"                   ,lcTabSeguro ,"DT_SINISTRO" 	          ,"D",  8,0,"",{|| getString2Date(lxVal,@lxRet)                              }})
   aadd(laProcs,{ 6,.T.,"nm_status_sinistro"              ,lcTabSeguro ,"TP_SINISTRO" 	          ,"C", 30,0,"",{|| chekTipoSinistro(lxVal,@lxRet)                            }})   // popular tipo_sinistro
   aadd(laProcs,{ 7,.T.,"nm_reclamante"                   ,lcTabSegRecl,"CIP_RECLAMANTE"          ,"C", 20,0,"",{|| getCipPfpj (lxVal,@lxRet,@lcCipReclama,"")                }})
   aadd(laProcs,{ 8,.T.,"cd_uf"                           ,lcTabSeguro ,"UF" 	                    ,"C",  2,0,"",{|| getAtualizaUF(lxVal,@lxRet)                               }})
   aadd(laProcs,{ 9,.T.,"nr_cnpj_cpf_segurado"            ,lcTabPfpj   ,"CNPJ_CPF"                ,"C", 15,0,"",{|| getVariavel(lxVal,@lxRet,@lcCnpjCpfSeg)                   }})	
   aadd(laProcs,{10,.T.,"nm_segurado"                     ,lcTabSegSdo ,"CIP_SEGURADO" 	          ,"C", 20,0,"",{|| getCipPfpj (lxVal,@lxRet,@lcCipSeguro,lcCnPjCpfSeg)       }})
   aadd(laProcs,{11,.F.,"nr_cnpj_cpf_sinistrado"          ,""          ,""                        ,"" ,  0,0,""})	
   aadd(laProcs,{12,.F.,"nm_sinistrado"                   ,""          ,""                     	  ,"" ,  0,0,""})
   * aadd(laProcs,{13,.F.,"cd_apolice"                     ,lcTabSeguro ,"CD_SUB_GRP_APOLICE"	     ,"N", 20,0,"",{|| getString2Numeric(lxVal,@lxRet,@lnNrApolice)              }})
   aadd(laProcs,{13,.F.,"cd_apolice"                      ,""          ,""	                      ,"",  0,0,"", {|| getString2Numeric(lxVal,@lxRet,@lnNrApolice)              }})
   aadd(laProcs,{14,.T.,"nr_endosso"                      ,lcTabSeguro ,"NR_ENDOSSO" 	            ,"N", 20,0,"",{|| getString2Numeric(lxVal,@lxRet)                           }})
   aadd(laProcs,{15,.T.,"nm_estipulante"                  ,lcTabSeguro ,"CIP_ESTIPULANTE"         ,"C", 20,0,"",{|| getCipPfpj (lxVal,@lxRet,@lcCipEstip)                     }})
   aadd(laProcs,{16,.T.,"nm_endereço_estipulante"         ,lcTabPfpj   ,"ENDERECO"                ,"C", 45,0,"",{|| getVariavel(lxVal,@lxRet,@lcEndereco)                     }})
   aadd(laProcs,{17,.F.,"nm_cep_cidade_uf_estipulante"    ,lcTabPfpj   ,"CEP"                     ,"C", 10,0,"",{|| getVariavel(lxVal,@lxRet,@lcCep)                          }})
   aadd(laProcs,{18,.F.,"nm_sub_estipulante"              ,lcTabPfpj   ,"EXTRA"                   ,"M", 10,0,"",{|| getVariavel(lxVal,@lxRet,@lcSubEstip)                     }})
   aadd(laProcs,{19,.F.,"nm_endereço_sub_estipulante"     ,lcTabPfpj   ,"NR_ENDERECO"             ,"N", 20,0,"",{|| getString2Numeric(lxVal,@lxRet,@lnNrEndereco)             }})
   aadd(laProcs,{20,.F.,"nm_cep_cidade_uf_sub_estipulante",lcTabPfpj   ,"CEP"                     ,"C", 10,0,"",{|| getVariavel(lxVal,@lxRet,@lcCepSub)                       }})
   aadd(laProcs,{21,.T.,"nm_causa"                        ,lcTabSeguro ,"RESUMO_SINDICANCIA"      ,"C", 20,0,"",{|| getVariavel(lxVal,@lxRet)                                 }})
   aadd(laProcs,{22,.F.,"nm_motivo_causa"                 ,""          ,""          	            ,"C", 30,0,"",{|| getSeguroCausaNis(lxVal,@lxRet,lnCdCausaNis)              }})  
   aadd(laProcs,{23,.F.,"nr_grupo_ramo"                   ,""          ,"" 	                      ,"",   0,0,""})
   aadd(laProcs,{24,.T.,"vl_pagamento"                    ,lcTabSeguro ,"VL_PREMIO_PAGO" 	        ,"N", 20,2,"",{|| getString2Numeric(lxVal,@lxRet)                           }})
   aadd(laProcs,{25,.T.,"nr_certificado"                  ,lcTabSeguro ,"NR_CERTIFICADO"          ,"C", 20,0,"",{|| getVariavel(lxVal,@lxRet)                                 }})
   aadd(laProcs,{26,.T.,"dt_emissao_apolice"              ,lcTabSeguro ,"DT_EMISSAO"              ,"D",  8,0,"",{|| getString2Date(lxVal,@lxRet)                              }})
   aadd(laProcs,{27,.T.,"dt_inicio_vigencia"              ,lcTabSeguro ,"DT_VIGENCIA_INI"         ,"D",  8,0,"",{|| getString2Date(lxVal,@lxRet)                              }})
   aadd(laProcs,{28,.T.,"dt_fim_vigencia"                 ,lcTabSeguro ,"DT_VIGENCIA_FIN"         ,"D",  8,0,"",{|| getString2Date(lxVal,@lxRet)                              }})
   aadd(laProcs,{29,.T.,"vl_premio"                       ,lcTabSeguro ,"VL_PREMIO"               ,"N", 20,2,"",{|| getString2Numeric(lxVal,@lxRet,@lnVlPremio)               }})
   aadd(laProcs,{30,.T.,"cd_tp_cosseguro"                 ,lcTabSeguro ,"TP_COSSEGURO"            ,"C", 30,0,"",{|| getVariavel(lxVal,@lxRet,@lcTpCosseg)                     }})
   aadd(laProcs,{31,.T.,"pc_cosseguro"                    ,lcTabSeguro ,"PC_COSSEGURO"            ,"N", 20,2,"",{|| getString2Numeric(lxVal,@lxRet,@lnPcCosseg)               }})
   aadd(laProcs,{32,.T.,"nm_resseguradora"                ,lcTabSeguro ,"CIP_FILIAL_ATEND"        ,"C", 20,0,"",{|| getCipFilialAtend(lxVal,@lxRet,@lcCipFilAte)              }})
   aadd(laProcs,{33,.T.,"pc_resseguro"                    ,lcTabSeguro ,"PC_RESSEGURO"            ,"N", 20,2,"",{|| getString2Numeric(lxVal,@lxRet,@lnPcResseg)               }})
   aadd(laProcs,{34,.T.,"vl_is_resseguro"                 ,lcTabSeguro ,"VL_RESSEGURO"            ,"N", 20,2,"",{|| getString2Numeric(lxVal,@lxRet,@lnVlResseg)               }})
   aadd(laProcs,{35,.T.,"dt_emissao_endosso"              ,lcTabSeguro ,"DT_CONTRATACAO"          ,"D",  8,0,"",{|| getString2Date(lxVal,@lxRet,@ldDtContra)                  }})
   aadd(laProcs,{36,.T.,"dt_inicio_vigencia_endosso"      ,lcTabSeguro ,"DT_CANCELAMENTO"         ,"D",  8,0,"",{|| getString2Date(lxVal,@lxRet)                              }})
   aadd(laProcs,{37,.T.,"dt_fim_vigencia_endosso"         ,lcTabSeguro ,"DT_VLESTIMADO"           ,"D",  8,0,"",{|| getString2Date(lxVal,@lxRet)                              }})
   aadd(laProcs,{38,.T.,"pc_cosseguro"                    ,lcTabSeguro ,"FL_COSSEGURO"            ,"C",  1,0,"",{|| getFlCosseguro(lxVal,@lxRet,@lcFlCosseg)                  }}) // OBSERVAÇÃO: SE pc_cosseguro não estiver vazio, alimentar FL_COSSEGURO com Y, caso contrário alimentar com N
   aadd(laProcs,{39,.T.,"pc_resseguro"                    ,lcTabSeguro ,"FL_RESSEGURO"            ,"C",  1,0,"",{|| getFlResseguro(lxVal,@lxRet,@lcFlResseg)                  }}) // OBSERVAÇÃO: SE pc_resseguro não estiver vazio, alimentar FL_RESSEGURO com Y, caso contrário alimentar com N
   aadd(laProcs,{40,.T.,"id_sin_pasta"                    ,lcTabSeguro ,"NR_SINISTRO_IRB"         ,"C", 20,0,"",{|| getVariavel(lxVal,@lxRet,@lcSiniIrb)                      }})
   * aadd(laProcs,{41,.F.,"id_produto_cobertura"             ,""          ,""                        ,"" ,  0,0,""})
   * aadd(laProcs,{41,.T.,"id_produto_coberura"             ,lcTabSeguro ,"NR_SINISTRO_FENASEG"     ,"C", 20,0,"",{|| getNrFenaseg(lxVal,@lxRet)                                }})
   aadd(laProcs,{41,.T.,"id_produto_coberura"             ,lcTabSeguro ,"NR_SINISTRO_FENASEG"     ,"C", 20,0,"",{|| getVariavel(lxVal,@lxRet,@lcSinFenaseg)                   }})
   aadd(laProcs,{42,.F.,"id_tp_motivo"                    ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{43,.T.,"nm_motivo_judicial"              ,lcTabSeguro ,"OBJETO_SINISTRO"         ,"C",250,0,"",{|| getVariavel(lxVal,@lxRet)                                 }})
   aadd(laProcs,{44,.F.,"dt_judicial"                     ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{45,.F.,"dt_citacao"                      ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{46,.T.,"nr_cnpj_cpf_autor"               ,lcTabSegVit ,"CNPJ_CPF"                ,"C", 15,0,"",{|| getVariavel(lxVal,@lxRet,@lcCnpjCpfVit)                   }})
   aadd(laProcs,{47,.T.,"nm_autor"                        ,lcTabSegVit ,"CIP_VITIMA"          	  ,"C", 20,0,"",{|| getCipPfpj (lxVal,@lxRet,@lcCipVitima,lcCnPjCpfVit)       }})
   aadd(laProcs,{48,.F.,"nm_status_pasta"                 ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{49,.F.,"nm_perda"                        ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{50,.T.,"vl_economico"                    ,lcTabSeguro ,"VL_ESTIMADO"             ,"N", 20,2,"",{|| getString2Numeric(lxVal,@lxRet)                           }})
   aadd(laProcs,{51,.F.,"vl_acao"                         ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{52,.T.,"cd_proposta"                     ,lcTabSeguro ,"NR_PROPOSTA"             ,"C", 20,0,"",{|| getVariavel(lxVal,@lxRet)                                 }})
   aadd(laProcs,{53,.F.,"nm_endereco_estipulante"         ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{54,.F.,"nm_endereco_sub_estipulante"     ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{55,.T.,"nm_corretor"                     ,lcTabSeguro ,"CIP_CORRETOR"            ,"C", 20,0,"",{|| getCipPfpj (lxVal,@lxRet,@lcCipCorre)                     }})
   aadd(laProcs,{56,.F.,"dt_demissao"                     ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{57,.F.,"dt_afastamento"                  ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{58,.F.,"id_followup"                     ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{59,.F.,"dt_followup"                     ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{60,.F.,"ds_followup"                     ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{61,.F.,"cd_retorno"                      ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{62,.F.,"nm_retorno"                      ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{63,.F.,"nm_cobertura"                    ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{64,.F.,"nr_grp_ramo"                     ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{65,.T.,"nr_ramo"                         ,lcTabSeguro ,"CD_RAMOSRSN"             ,"C",  7,0,"",{|| chekRamoSrSn(lxVal,@lxRet)                                }}) // ramosrsn
   aadd(laProcs,{66,.T.,"vl_aviso"                        ,""          ,""                        ,"",   0,0,"",{|| getString2Numeric(lxVal,@lxRet,@lnVlAviso)                }})
   aadd(laProcs,{67,.T.,"vl_is"                           ,""          ,""                        ,"",   0,0,"",{|| getString2Numeric(lxVal,@lxRet,@lnVlLmi)                  }}) // pasta_seguro_lmi VL_LMI
   aadd(laProcs,{68,.T.,"vl_reserva"                      ,lcTabSeguro ,"VL_RESERVA"              ,"N", 20,2,"",{|| getString2Numeric(lxVal,@lxRet)                           }})
   aadd(laProcs,{69,.F.,"nm_obs"                          ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{70,.F.,"nm_linha_digitavel"              ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{71,.F.,"dt_cancelamento"                 ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{72,.F.,"id_tp_motivo_cancelamento"       ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{73,.F.,"motivo_cancelamento"             ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{74,.F.,"id_pessoa_beneficiario"          ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{75,.F.,"nm_beneficiario"                 ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{76,.F.,"nm_parentesco"                   ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{77,.F.,"pc_participacao_segurado"        ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{78,.F.,"dv_cosseguro"                    ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{79,.F.,"nm_lider"                        ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{80,.F.,"id_pessoa_congenere"             ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{81,.F.,"nm_congenere"                    ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{82,.F.,"vl_is_cosseguro"                 ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{83,.F.,"vl_premio_cosseguro"             ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{84,.F.,"dv_cosseguro"                    ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{85,.F.,"nm_lider"                        ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{86,.F.,"id_pessoa_congenere"             ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{87,.F.,"nm_congenere"                    ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{88,.F.,"vl_is_cosseguro"                 ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{89,.F.,"vl_premio_cosseguro"             ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{90,.F.,"dv_resseguro"                    ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{91,.F.,"id_pessoa_resseguradora"         ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{92,.F.,"vl_premio_resseguro"             ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{93,.F.,"nto"                             ,""          ,""                        ,"",   0,0,""})
   aadd(laProcs,{94,.T.,"nm_cobertura"                    ,""          ,""                        ,"C",200,0,"",{|| getVariavel(lxVal,@lxRet,@lcNmCobert)                      }})  // pasta_seguro_lmi
   aadd(laProcs,{95,.T.,""                                ,lcTabSeguro ,"NR_APOLICE"              ,"C", 20,0,"",{|| getValorVariavel(lxVal,@lxRet,alltrim(str(lnNrApolice)))   }})  // pasta_seguro.NR_APOLICE
   aadd(laProcs,{96,.T.,""                                ,lcTabSeguro ,"FL_STATUSINTERFACE"      ,"C",  1,0,"",{|| getValorVariavel(lxVal,@lxRet,"3")                         }})  // pasta_seguro.FL_STATUSINTERFACE
   *              1  2       3                             4             5                         6     7 8 9             10 

   lcMess:= "Processando o Retorno de Dados de Sinistro do I4Pro"
   dispMessage(pnHOcor,lcMess)
   
   laTemp:= directory(fcPath + fcFile + "*.RET")
   
   for ii:= 1 to len(laTemp)
   
      lcFile:= alltrim(laTemp[ii,1])
      aadd(laFiles,lcFile)
      
   next ii
   
   laFiles:= asort(laFiles)
   
   for ii:= 1 to len(laFiles)
   
      lcFile:= fcPath + laFiles[ii]
      lcMess:= space(3) + "Arquivo: " + lcFile
      dispMessage(pnHOcor,lcMess)
      
      lnHFile:= fopen(lcFile)
      if lnHFile > 0
         lcBuffer:= space(lnBuffer)
         llEof   := .F.
         lnRecoun:= 0
         
         while ! llEof
         
            lcLine:= alltrim(freadtxt(lnHFile,@lcBuffer,lnBuffer,@llEof))
            lnRecoun:= lnRecoun + 1
            
         enddo
      
         fclose(lnHFile)
      else
         lcMess:= space(3) + "??? Problemas na abertura do arquivo: " + lcFile
         llFlg := .F.
         exit
      endif
      if llFlg
         lnHFile:= fopen(lcFile)
         if lnHFile > 0
            lcBuffer:= space(lnBuffer)
            llEof   := .F.
         
            lcMess:= "Processando a atualização de dados de retorno - Aguarde ..."
            dispMessage(pnHOcor,lcMess)
         
            while ! llEof
         
               lcLine:= alltrim(freadtxt(lnHFile,@lcBuffer,lnBuffer,@llEof))
               if ! empty(lcLine)

                 laValString := getString2Array(lcLine)

                  dispProcess(@lnCurRow,@lnRefRow,lnMaxRow,lnRecoun,pnHOcor,.f.,.f.)      

                  * limpando a coluna de valores
                  for nn:= 1 to len(laProcs)
               
                     laProcs[nn,9]:= ""
                  
                  next nn
         
                  laValCobert := {}
                  laValAviso  := {}
                  laValIS     := {}
               
                  * obtendo os valores do array
                  llGoOn    := .T.
                  lcTagErro := ""
                  lcMensErro:= ""

                  for nn:= 1 to len(laValString)
               
                     lcTagName:= lower(alltrim(laValString[nn,1]))
                     lcTagVal := alltrim(laValString[nn,2])
                     if empty(lcTagName)
                        loop
                     endif
                     if lcTagName == "cd_retorno" .and.;
                        lcTagVal  == "01"
                        lcTagErro := lcTagVal
                     endif   
                     if lcTagErro == "01" .and.;
                        lcTagName == "nm_retorno"
                        lcMensErro:= lcTagVal
                     endif
                     xx:= ascan(laProcs,{|x| x[3] == lcTagName})
                     if xx > 0
                        * if lcTagName == "nm_cobertura"
                        if lcTagName == "nm_cobertura"
                           aadd(laValCobert,{lcTagName,lcTagVal})              
                        endif
                        if lcTagName == "vl_aviso"    
                           aadd(laValAviso,{lcTagName,val(lcTagVal)})
                        endif
                        if lcTagName == "vl_is"
                           aadd(laValIs,{lcTagName,val(lcTagVal)})
                        endif
                        if empty(laProcs[xx,9])
                           * como pode existir mais de 1 vez o nome da tag do xml, entao considera o primeiro que tiver valor
                           laProcs[xx,9]:= lcTagVal
                        endif   
                     else
                        lcMess:= space(3) + "??? TAG nao localizada: " + lcTagName
                        dispMessage(pnHOcor,lcMess)
                     endif
                  
                  next nn

                  * verificando se o retorno do registro foi informado como: cd_retorno="01" nm_retorno="Sinistro não encontrado."

                  if lcTagErro == "01"
                     lcMess:= space(3) + "??? Retorno com mensagem de erro: NR_SINISTRO: " + lcNrSinistro + " - NM_RETORNO = " + lcMensErro
                     dispMessage(pnHOcor,lcMess)
                     llGoOn:= .F.
                     loop
                  endif
               
                  laStruSeguro:= {}
                  laUCols     := {}
                  laVals      := {}
                
                  for nn:= 1 to len(laProcs) 

                     if len(laProcs[nn]) > 9
                        lxVal:= laProcs[nn,9]
                        if valtype(laProcs[nn,10]) == "B"
                           lbProc:= laProcs[nn,10]
                           eval(lbProc)
                           laProcs[nn,9]:= lxRet
                        endif
                     endif
                     if laProcs[nn,2]
                        if laProcs[nn,4] == lcTabSeguro
                           aadd(laStruSeguro,{laProcs[nn,5],laProcs[nn,6],laProcs[nn,7],laProcs[nn,8]})
                           aadd(laUCols,laProcs[nn,5])
                           aadd(laVals,laProcs[nn,9])
                        endif
                     endif

                  next nn        

                  for nn:= 1 to len(laValAviso)
                  
                     if laValAviso[nn,2] > 0
                         * recuperando os valores das variaveis, pois havendo mais de 1 tag no xml, o último pode estar sem conteudo
                        if nn <= len(laValCobert) .and.;
                           nn > 0
                           lcNmCobert:= alltrim(laValCobert[nn,2])
                        else
                           lcNmCobert:= ""
                        endif
                        lnVlAviso := laValAviso[nn,2]
                        if nn <= len(laValIs) .and.;
                           nn > 0
                           lnVlLmi   := laValIs[nn,2]
                        else
                           lnVlLmi   := 0
                        endif   
                        exit
                     endif
                     
                  next nn

                  lnNrPasta   := int(lnNrPasta)

                  lnNrControle:= 0
                  if len(laUCols) > 0
                     if lnNrPasta > 0 .and.;
                        ! empty(lcNrSinistro)
                        laValues:= {}
                        aadd(laValues,laUCols)
                        aadd(laValues,laVals)
                  
                        laWhere:= {}
                        aadd(laWhere,"NR_PASTA = "     + alltrim(str(lnNrPasta)))
                        aadd(laWhere,"NR_SINISTRO = '" + alltrim(lcNrSinistro) + "'")
                     
                        lnError:= db_select(laSCols,lcTabSeguro, , laWhere)
                        if lnError == -1
                           lcMess:= space(3) + "??? Problemas na pesquisa na tabela: " + lcTabSeguro
                           llFlg := .F.
                           exit
                        endif
                        laResSeguro:= db_fetchrow()
                        if len(laResSeguro) > 0
                           lnNrControle:= laResSeguro[2]

                           laWhere:= {}
                           aadd(laWhere,"NR_PASTA = "    + alltrim(str(lnNrPasta)))
                           aadd(laWhere,"NR_CONTROLE = " + alltrim(str(lnNrControle)))
                        
                           if lnNrControle > 0
                              *                      1          2         3    4 5 6 7
                              lnError:= db_update(laValues,lcTabSeguro,laWhere, , , ,laStruSeguro)
                              if lnError == -1
                                 lcMess:= space(3) + "??? Problemas na alteraçao na tabela: " + lcTabSeguro
                                 llFlg := .F.
                                 exit
                              endif
                           endif
                        else
                           lcMess:= space(3) + "??? Sinistro Nao Localizado: NR_PASTA = " + alltrim(str(lnNrPasta)) + " - NR_SINISTRO: " + lcNrSinistro
                           dispMessage(pnHOcor,lcMess)
                           loop
                        endif   
                     endif
                     * excluindo pasta_seguro_segurado, pasta_seguro_vitima, pasta_seguro_reclamante, pasta_seguro_lmi
                     if ! excPastaSeguroRelacionadas(lnNrPasta,lnNrControle)
                        lcMess:= space(3) + "??? Problemas na exclusao de dados das tabelas relacionadas a pasta_seguro"
                        llFlg := .F.
                        exit
                     endif
                     *
                     * segurado
                     if ! empty(lcCipSeguro)
                        if ! getSeguroSegurado(lnNrPasta,lnNrControle,lcCipSeguro)
                           lcMess:= space(3) + "??? Problemas na manutençao da tabela: pasta_seguro_segurado"
                           llFlg := .F.
                           exit
                        endif
                     endif   
                     * vitima
                     if ! empty(lcCipVitima)
                        if ! getSeguroVitima(lnNrPasta,lnNrControle,lcCipVitima)
                           lcMess:= space(3) + "??? Problemas na manutençao da tabela: pasta_seguro_vitima"
                           llFlg := .F.
                           exit
                        endif
                     endif
                     * reclamante
                     if ! empty(lcCipReclama)
                        if ! getSeguroReclamante(lnNrPasta,lnNrControle,lcCipReclama)
                           lcMess:= space(3) + "??? Problemas na manutençao da tabela: pasta_seguro_reclamante"
                           llFlg := .F.
                           exit
                        endif
                     endif   

                     if ! empty(lcNmCobert) 
                        if ! checkSeguroLmi(lnNrPasta,lnNrControle,lcNmCobert,lnVlLmi,lnVlAviso)
                           lcMess:= space(3) + "??? Problemas na manutençao da tabela: pasta_seguro_lmi"
                           llFlg := .F.
                           exit
                        endif
                     endif   
                  endif
               endif   
               
            enddo
            
            if llFlg
               dispProcess(lnCurRow,lnRefRow,lnMaxRow,lnRecoun,pnHOcor,.t.,.f.)      
            endif
            fclose(lnHFile)
         else
            lcMess:= space(3) + "??? Problemas na abertura do arquivo: " + lcFile
            llFlg := .F.
            exit
         endif
      endif
      
   next ii
   
   if ! llFlg
      dispMessage(pnHOcor,lcMess)
   endif
   plFlg:= llFlg
      
return (llFlg)
/*
* Function..: getString2Array()
* Objective.: converter string em array
* Parameters:
*   fcStr...: string
* Return....: array  
*/
function getString2Array(fcStr)
   local ii        := 0,;
         nn        := 0,;
         xx        := 0  // as int
   local lcSepara  := '" ',;
         lcLine    := "",;
         lcTitle   := "",;
         lcValue   := "",;
         lcVal     := "" // as string
   local laArray   := {},;
         laTemp    := {} // as array
         
   lcLine:= fcStr
         
   xx:= at(space(1),lcLine)
   if xx > 0
      lcLine:= alltrim(substr(lcLine,xx+1))
   endif
         
   while .t.
   
     nn:= at(lcSepara,lcLine)

     if nn > 0
        xx:= at('"',lcLine)
        lcVal  := alltrim(substr(lcLine,1,nn))
        lcLine := alltrim(substr(lcLine,nn+1))

        for ii:= nn to 1 step -1
        
           if substr(lcVal,ii,1) == space(1)
              lcVal:= alltrim(substr(lcVal,ii))
              exit
           endif
           
        next ii

        aadd(laTemp,lcVal)
     else
        aadd(laTemp,lcLine)
        exit   
     endif

   enddo
         
   for ii:= 1 to len(laTemp) 
   
      lcLine:= alltrim(laTemp[ii])
      
      xx:= at('="',lcLine)
      if xx > 0
         lcTitle:= alltrim(substr(lcLine,1,xx-1))
         lcValue:= alltrim(substr(lcLine,xx+2))

         xx:= at('"',lcValue)
         if xx > 0
            lcValue:= substr(lcValue,1,xx-1)
         else 
            lcValue:= alltrim(strtran(lcValue,'"',''))
         endif
         aadd(laArray,{lcTitle,lcValue})
      endif

   next ii
        
return (laArray)
/*
* Function..: preparaValorTags()
* Objective.: obter os valores da tags na linha
* Parameters:
*   fcLine..: linha com as tags e valores
*   faPrs...: array com estrutura das tags
* Return....: array com dados  
* aadd(laProcs,{17,.T."id_produto_cobertura"       ,lcTabSeguro,"NR_SINISTRO_FENASEG","C",20,0,""})
*                1  2            3                    4                5              6   7 8  9
*/
function preparaValorTags(fcLine,faPrs)
   local llFlg       := .T. // as logical
   local ii          := 0,;
         xx          := 0   // as int
   local lxValue          
   local lcTagName   := "",;
         lcValue     := "",;
         lcMess      := ""  // as string
   local laValues    := {},;
         laTemp      := {}  // as array
   
   for ii:= 1 to len(faPrs)
   
      lcTagName:= lower(alltrim(faPrs[ii,3]))
      
      xx:= at(lcTagName,lower(fcLine))
      if xx > 0
         lcValue:= substr(fcLine,xx)
         
         xx:= at('"',lcValue)
         if xx > 0
            lcValue:= substr(lcValue,xx+1)
            xx:= at('"',lcValue)
            if xx > 0
               lcValue:= alltrim(substr(lcValue,1,xx-1))
               
               if faPrs[ii,6] == "C" 
                  lxValue:= alltrim(lcValue)
               elseif faPrs[ii,6] == "D"
                  lcValue:= strtran(lcValue,"-","/")
                  lxValue:= ctod(lcValue)
               elseif faPrs[ii,6] == "N"
                  lxValue:= val(alltrim(lcValue))
               endif
                             
               laTemp:= {}
               aadd(laTemp,lcTagName)
               aadd(laTemp,lxValue)
               aadd(laTemp,.T.)

               aadd(laValues,laTemp)
            endif
         endif
      else
         * quando nao encontrar a tag, não processa a alteração da coluna da tag correspondente
         lxValue:= ""
         laTemp := {}
         aadd(laTemp,lcTagName)
         aadd(laTemp,lxValue)
         aadd(laTemp,.F.)

         aadd(laValues,laTemp)
      endif
      
   next ii
   
   if ! llFlg
      dispMessage(pnHOcor,lcMess)
   endif
   plFlg:= llFlg
   
return (laValues)
/*
* Function..: preparaDadosArquivo()
* Objective.: preparar array com dados do arquivo
* Parameters:
*   fcFile..: arquivo
* Return....: array
* Comments..: 
*   estrutura do array para capturar os valores
*   aadd(laProcs,{17,"id_produto_cobertura"       ,lcTabSeguro,"NR_SINISTRO_FENASEG","C",20,0,""})
*                 1       2                           3            5                5   6 7  8
*/
function preparaDadosArquivo(fcFile)
   local llFlg      := .T.,;
         llEof      := .F. // as logical
   local lnBuffer   := 512,;
         lnHFile    := 0,;
         xx         := 0   // as int
   local lcBuffer   := space(lnBuffer),;
         lcFinal    := "</i4proerp>",;
         lcString   := "",;
         lcLine     := "",;
         lcMess     := ""  // as strinf
   local laFileVals := {}  // as array
   
   lnHFile:= fopen(fcFile,0)
   if lnHFile > 0
      lcString:= ""
      
      while ! llEof
      
         lcLine:= alltrim(freadtxt(lnHFile,@lcBuffer,lnBuffer,@llEof))
         if ! empty(lcLine)
            if substr(lcLine,len(lcLine) - len(lcFinal) + 1,len(lcFinal)) == lcFinal
               lcString+= lcLine
               aadd(laFileVals,lcString)
               lcString:= ""
            else
               lcString+= lcLine
            endif
         endif
         
      enddo
      
      fclose(lnHFile)
   else
      lcMess:= space(3) + "??? Problemas na abertura do arquivo: " + fcFile
      llFlg := .F.
   endif

   if ! llFlg
      dispMessage(pnHOcor,lcMess)
   endif
   plFlg := llFlg
   
return (laFileVals)
/*
* Function..: geraEnvioXml()
* Objective.: gerar um arquivo xml com os dados
* Parameters:
*   fnXml...: handle do arquivo de saida
*   faVals..: array com dados
*   faTabs..: array com estrutura do arquivo
* Return....: .t./.f.
*   .t. processado com sucesso
*   .f. problemas no processamento
* Comments..:
*  1 aadd(laTables,{.F.   ,"SEQ","CAMPO"               ,"TIPO"         ,"DESCRIÇÃO"                  ,""                  ,"X",  0,0,""          ,"''"         }) //  0
*  2 aadd(laTables,{.F.   ,00   ,"NR_CONTROLE_SEGURO"  ,"BIGINT"       ,"NÚMERO DE CONTROLE"         ,""                  ,"N", 20,0,lcTabSeguro ,"NR_CONTROLE",{|| getVariavel(lxVal,@lxRet,@lnNrContSeg)}}) //  1  pasta_seguro.NR_SINISTRO
*  3 aadd(laTables,{.T.   ,01   ,"NR_SINISTRO"         ,"BIGINT"       ,"NÚMERO DO SINISTRO"         ,""                  ,"N", 20,0,lcTabSeguro ,"NR_SINISTRO",{|| getSomenteNumeros(lxVal,@lxRet,@lcNrSinistro)}}) //  1  pasta_seguro.NR_SINISTRO
*  4 aadd(laTables,{.T.   ,02   ,"NR_PASTA"            ,"VARCHAR(15)"  ,"NÚMERO DA PASTA JUDICIAL"   ,""                  ,"C", 15,0,lcTabPasta  ,"NR_PASTA"   ,{|| getVariavel(lxVal,@lxRet,@lnNrPasta)}}) //  2  pasta.NR_PASTA
*  5 aadd(laTables,{.T.   ,03   ,"DT_CITACAO"          ,"VARCHAR(10)"  ,"DATA DA CITAÇÃO"            ,"(DD-MM-AAAA)"      ,"D",  8,0,lcTabPasta  ,"DT_CITACAO" ,{|| getVariavel(lxVal,@lxRet,ldDtCitacao)}}) //  3  pasta.DT_CITACAO
*  6 aadd(laTables,{.T.   ,04   ,"ID_PESSOA_AUTOR"     ,"INT"          ,"CÓDIGO DO AUTOR"            ,""                  ,"N", 20,0,lcTabPrt    ,"CIP"        ,{|| getVariavel(lxVal,@lxRet,@lcCipPrt)}}) //  4  CIP_PARTE_CONTRARIA
*  7 aadd(laTables,{.T.   ,05   ,"NM_AUTOR"            ,"VARCHAR(100)" ,"NOME DO AUTOR"              ,""                  ,"C",100,0,lcTabPrt    ,"PFPJ"       ,{|| getVariavel(lxVal,@lxRet,lcPfpjPrt)}}) //  5  pasta_pfpj_parte_contraria.PFPJ
*  8 aadd(laTables,{.T.   ,06   ,"NR_CNPJ_CPF_AUTOR"   ,"BIGINT"       ,"CPF OU CNPJ DO AUTOR"       ,""                  ,"N", 20,0,lcTabPfpjPrt,"CNPJ_CPF"   ,{|| getSomenteNumeros(lxVal,@lxRet,@lcCnpjCpfPrt)}}) //  6  CNPJ_CPF da parte contrária
*  9 aadd(laTables,{.T.   ,07   ,"CD_UF",              ,"VARCHAR(2)"   ,"UF"                         ,"NÃO SERÁ INFORMADO","C",  2,0,lcTabPasta  ,"UF"         ,{|| getPastaUf(lxVal,@lxRet,@lcUf)}}) //  7  pasta.UF com space(2)
* 10 aadd(laTables,{.T.   ,08   ,"NM_PERDA"            ,"VARCHAR(30)"  ,"TIPO DE PERDA"              ,""                  ,"C", 30,0,lcTabExito  ,"RISCOPERDA" ,{|| getVariavel(lxVal,@lxRet,@lcRiscoPerda)}}) //  8  pasta.PC_RISCO exito_riscoperda.NM_
* 11 aadd(laTables,{.T.   ,09   ,"VL_ECONOMICO"        ,"NUMERIC"      ,"VALOR ECONÔMICO DO PROCESSO",""                  ,"N", 20,0,lcTabPasta  ,"VL_RISCO"   ,{|| getVariavel(lxVal,@lxRet,@lnVlRisco)}}) //  9  pasta.VL_ACAO
* 12 aadd(laTables,{.T.   ,10   ,"VL_ACAO"             ,"NUMERIC"      ,"VALOR DA AÇÃO"              ,""                  ,"N", 20,2,lcTabPasta  ,"VL_RISCO"   ,{|| getValorVariavel(lxVal,@lxRet,lnVlRisco)}}) // 10  pasta.VL_ACAO
* 13 aadd(laTables,{.T.   ,11   ,"VL_PAGAMENTO"        ,"NUMERIC"      ,"VALOR DO PAGAMENTO"         ,""                  ,"N", 20,2,""          ,"0.00"               ,{|| getValorVariavel(lxVal,@lxRet,0.00)}}) // 11  a ser informado
* 14 aadd(laTables,{.T.   ,12   ,"NR_PROCESSO_JUDICIAL","VARCHAR(20)"  ,"NÚMERO DO PROCESSO JUDICIAL",""                  ,"N", 20,0,lcTabPasta  ,"NR_PROCESSO"        ,{|| getVariavel(lxVal,@lxRet,@lcNrProcesso)}}) // 12  pasta.NR_PROCESSO
* 15 aadd(laTables,{.T.   ,13   ,"NM_RECLAMANTE"       ,"VARCHAR(100)" ,"NOME DO RECLAMANTE"         ,"NÃO SERÁ INFORMADO","C",100,0,lcTabRec    ,"PFPJ"               ,{|| getVariavel(lxVal,@lxRet,@lcPfpjRec)}}) // 13  a ser informado
* 16 aadd(laTables,{.T.   ,14   ,"ID_MOTIVO_JUDICIAL"  ,"INT"          ,"MOTIVO JUDICIAL"            ,""                  ,"N", 20,0,lcTabSeguro ,"OBJETO_SINISTRO"    ,{|| getVariavel(lxVal,@lxRet,@lcObjSinist)}}) // 14  a ser informado
* 17 aadd(laTables,{.T.   ,15   ,"NR_RAMO"             ,"INT"          ,"NÚMERO DO RAMO"             ,"NÃO SERÁ INFORMADO","N", 20,0,lcTabSeguro ,"CD_RAMOSRSN"        ,{|| getVariavel(lxVal,@lxRet,@lcRamoSrSn)}}) // 15  a ser informado
* 18 aadd(laTables,{.T.   ,16   ,"ID_PRODUTO_COBERTURA","INT"          ,"CÓDIGO DA COBERTURA"        ,"NÃO SERÁ INFORMADO","N", 20,0,lcTabSeguro ,"NR_SINISTRO_FENASEG",{|| getVariavel(lxVal,@lxRet,@lcFenaseg)}}) // 16  a ser informado   
* 19 aadd(laTables,{.T.   ,17   ,"NM_COBERTURA"        ,"VARCHAR(100)" ,"NOME DA COBERTURA"          ,"NÃO SERÁ INFORMADO","C",100,0,lcTabSegLmi ,"LMI_NM_COBERTURA"   ,{|| getValorVariavel(lxVal,@lxRet,@lcNmCobert)}}) // 17  a ser informado
* 20 aadd(laTables,{.T.   ,18   ,"VL_ATUALIZADO_TOTAL" ,"NUMERIC"      ,"VALOR DA RESERVA"           ,"NOVO ATRIBUTO"     ,"N", 20,2,""          ,"0"          ,{|| getValorReserva(lxVal,@lxRet,@lnVlReserva,lnNrPasta,lnNrContSeg)}}) // 18  pasta_pedidos somatória VL_RISCO_CALC, VL_CORRECAO + VL_JUROS 
* <i4proerp>
*   <MarcarSinistroJudicial 
*     nr_sinistro ="90193194863101"                           1
*     nr_pasta ="84943"                                       2
*     dt_citacao ="15-05-2018"                                3
*     id_pessoa_autor ="21414"                                4
*     nm_autor ="LUIS FERNANDO ALVES LOPES DOS SANTOS"        5
*     nr_cnpj_cpf_autor ="21256666858"                        6
*     cd_uf =""                                               7
*     nm_perda ="REMOTA"                                      8
*     vl_economico ="50000.00"                                9
*     vl_acao ="50000.00"                                    10
*     vl_pagamento ="0.00"                                   11
*     nr_processo_judicial ="028262553"                      12
*     nm_reclamante = ""                                     13
*     id_motivo_judicial ""                                  14
*     nr_ramo = ""                                           15
*     id_produto_cobertura = "                               16
*     nm_cobertura = ""                                      17
*     vl_atualizado_total = “150000.00”/>                    18
* </i4proerp>
*/
function geraEnvioXml(fnXml,faVals,faTabs)
   local llFlg       := .T. // as logical
   local lnHFile     := 0,;
         lnNrPasta   := 0,;
         ii          := 0   // as int
   local lxValue      
   local lcFile      := "",;
         lcNrSinistro:= "",;
         lcVal       := "",;
         lcLine      := "",;
         lcMess      := ""  // as string
   local laTables    := {}  // as array

   public pnHXml := 0
   
   * aadd(laTables,{.F.   ,"SEQ","CAMPO"               ,"TIPO"         ,"DESCRIÇÃO"                  ,""                  ,"X",  0,0,""          ,"''"                 })                                                    //  1
   * aadd(laTables,{.F.   ,00   ,"NR_CONTROLE_SEGURO"  ,"BIGINT"       ,"NÚMERO DE CONTROLE"         ,""                  ,"N", 20,0,lcTabSeguro ,"NR_CONTROLE"        ,{|| getVariavel(lxVal,@lxRet,@lnNrContSeg)}})        //  2  pasta_seguro.NR_SINISTRO
   * aadd(laTables,{.T.   ,01   ,"NR_SINISTRO"         ,"BIGINT"       ,"NÚMERO DO SINISTRO"         ,""                  ,"N", 20,0,lcTabSeguro ,"NR_SINISTRO"        ,{|| getSomenteNumeros(lxVal,@lxRet,@lcNrSinistro)}}) //  3  pasta_seguro.NR_SINISTRO
   * aadd(laTables,{.T.   ,02   ,"NR_PASTA"            ,"VARCHAR(15)"  ,"NÚMERO DA PASTA JUDICIAL"   ,""                  ,"C", 15,0,lcTabPasta  ,"NR_PASTA"           ,{|| getVariavel(lxVal,@lxRet,@lnNrPasta)}})          //  4  pasta.NR_PASTA
   * aadd(laTables,{.T.   ,03   ,"DT_CITACAO"          ,"VARCHAR(10)"  ,"DATA DA CITAÇÃO"            ,"(DD-MM-AAAA)"      ,"D",  8,0,lcTabPasta  ,"DT_CITACAO"         ,{|| getVariavel(lxVal,@lxRet,ldDtCitacao)}})         //  5  pasta.DT_CITACAO
   * aadd(laTables,{.T.   ,04   ,"ID_PESSOA_AUTOR"     ,"INT"          ,"CÓDIGO DO AUTOR"            ,""                  ,"N", 20,0,lcTabPrt    ,"CIP"                ,{|| getVariavel(lxVal,@lxRet,@lcCipPrt)}})           //  6  CIP_PARTE_CONTRARIA
   * aadd(laTables,{.T.   ,05   ,"NM_AUTOR"            ,"VARCHAR(100)" ,"NOME DO AUTOR"              ,""                  ,"C",100,0,lcTabPrt    ,"PFPJ"               ,{|| getVariavel(lxVal,@lxRet,lcPfpjPrt)}})           //  7  pasta_pfpj_parte_contraria.PFPJ
   * aadd(laTables,{.T.   ,06   ,"NR_CNPJ_CPF_AUTOR"   ,"BIGINT"       ,"CPF OU CNPJ DO AUTOR"       ,""                  ,"N", 20,0,lcTabPfpjPrt,"CNPJ_CPF"           ,{|| getSomenteNumeros(lxVal,@lxRet,@lcCnpjCpfPrt)}}) //  8  CNPJ_CPF da parte contrária
   * aadd(laTables,{.T.   ,07   ,"CD_UF",              ,"VARCHAR(2)"   ,"UF"                         ,"NÃO SERÁ INFORMADO","C",  2,0,lcTabPasta  ,"UF"                 ,{|| getPastaUf(lxVal,@lxRet,@lcUf)}})                //  9  pasta.UF com space(2)
   * aadd(laTables,{.T.   ,08   ,"NM_PERDA"            ,"VARCHAR(30)"  ,"TIPO DE PERDA"              ,""                  ,"C", 30,0,lcTabExito  ,"RISCOPERDA"         ,{|| getRiscoPerda(lxVal,@lxRet,@lcRiscoPerda)}})     // 10  pasta.PC_RISCO exito_riscoperda.NM_
   * aadd(laTables,{.T.   ,09   ,"VL_ECONOMICO"        ,"NUMERIC"      ,"VALOR ECONÔMICO DO PROCESSO",""                  ,"N", 20,0,lcTabPasta  ,"VL_CAUSA"           ,{|| getVariavel(lxVal,@lxRet,@lnVlRisco)}})          // 11  pasta.VL_ACAO
   * aadd(laTables,{.T.   ,10   ,"VL_ACAO"             ,"NUMERIC"      ,"VALOR DA AÇÃO"              ,""                  ,"N", 20,2,lcTabPasta  ,"VL_CAUSA"           ,{|| getValorVariavel(lxVal,@lxRet,lnVlRisco)}})      // 12  pasta.VL_ACAO
   * aadd(laTables,{.T.   ,11   ,"VL_PAGAMENTO"        ,"NUMERIC"      ,"VALOR DO PAGAMENTO"         ,""                  ,"N", 20,2,""          ,"0.00"               ,{|| getValorVariavel(lxVal,@lxRet,0.00)}})           // 13  a ser informado
   * aadd(laTables,{.T.   ,12   ,"NR_PROCESSO_JUDICIAL","VARCHAR(20)"  ,"NÚMERO DO PROCESSO JUDICIAL",""                  ,"N", 20,0,lcTabPasta  ,"NR_PROCESSO"        ,{|| getVariavel(lxVal,@lxRet,@lcNrProcesso)}})       // 14  pasta.NR_PROCESSO
   * aadd(laTables,{.T.   ,13   ,"NM_RECLAMANTE"       ,"VARCHAR(100)" ,"NOME DO RECLAMANTE"         ,"NÃO SERÁ INFORMADO","C",100,0,lcTabRec    ,"PFPJ"               ,{|| getVariavel(lxVal,@lxRet,@lcPfpjRec)}})          // 15  a ser informado
   * aadd(laTables,{.T.   ,14   ,"ID_MOTIVO_JUDICIAL"  ,"INT"          ,"MOTIVO JUDICIAL"            ,""                  ,"N", 20,0,lcTabSeguro ,"OBJETO_SINISTRO"    ,{|| getValorVariavel(lxVal,@lxRet,"601")}})          // 16  a ser informado
   * aadd(laTables,{.T.   ,15   ,"NR_RAMO"             ,"INT"          ,"NÚMERO DO RAMO"             ,"NÃO SERÁ INFORMADO","N", 20,0,lcTabSeguro ,"CD_RAMOSRSN"        ,{|| getVariavel(lxVal,@lxRet,@lcRamoSrSn)}})         // 17  a ser informado
   * aadd(laTables,{.T.   ,16   ,"ID_PRODUTO_COBERTURA","INT"          ,"CÓDIGO DA COBERTURA"        ,"NÃO SERÁ INFORMADO","N", 20,0,lcTabSeguro ,"NR_SINISTRO_FENASEG",{|| getVariavel(lxVal,@lxRet,@lcFenaseg)}})          // 18  a ser informado   
   *    aadd(laTables,{.T.   ,17   ,"NM_COBERTURA"        ,"VARCHAR(100)" ,"NOME DA COBERTURA"          ,"NÃO SERÁ INFORMADO","C",100,0,lcTabSegLmi ,"LMI_NM_COBERTURA"   ,{|| getValorVariavel(lxVal,@lxRet,@lcNmCobert)}})  // 18  a ser informado
   * aadd(laTables,{.T.   ,18   ,"VL_ATUALIZADO_TOTAL" ,"NUMERIC"      ,"VALOR DA RESERVA"           ,"NOVO ATRIBUTO"     ,"N", 20,2,""          ,"0"                  ,{|| getValorReserva(lxVal,@lxRet,@lnVlReserva,lnNrPasta,lnNrContSeg)}}) // 19  pasta_pedidos somatória VL_RISCO_CALC, VL_CORRECAO + VL_JUROS 
   * aadd(laTables,{.T.   ,19   ,"VL_RISCO_CALC"       ,"NUMERIC"      ,"VALOR DO RISCO CALCULADO"   ,"NOVO ATRIBUTO"     ,"N", 20,2,""          ,"0"                  ,{|| getValorVariavel(lxVal,@lxRet,@lnVlRisCalc)}})   // 21  pasta_pedidos somatória VL_RISCO_CALC, VL_CORRECAO + VL_JUROS 
   * aadd(laTables,{.T.   ,20   ,"VL_CORRECAO"         ,"NUMERIC"      ,"VALOR DA CORRECAO"          ,"NOVO ATRIBUTO"     ,"N", 20,2,""          ,"0"                  ,{|| getValorVariavel(lxVal,@lxRet,@lnVlCorrecao)}})  // 22  pasta_pedidos somatória VL_RISCO_CALC, VL_CORRECAO + VL_JUROS 
   * aadd(laTables,{.T.   ,21   ,"VL_JUROS"            ,"NUMERIC"      ,"VALOR DOS JUROS"            ,"NOVO ATRIBUTO"     ,"N", 20,2,""          ,"0"                  ,{|| getValorVariavel(lxVal,@lxRet,@lnVlJuros)}})     // 23  pasta_pedidos somatória VL_RISCO_CALC, VL_CORRECAO + VL_JUROS 
      
   * 1 nome da coluna
   * 2 conteudo a ser copiado
   * 3 caracter de finalizado da linha
   * 4 posicao no array do faVals (array de entrada gerado na função acima)
   * 5 tipo de caracter na origem no array de entrada (na saida sempre deve gravar no formato caracter)
   *                     1                         2  3    4  5
   aadd(laTables,{'<i4proerp>'              ,"",""  , 0,"" }) //  1
   aadd(laTables,{'<MarcarSinistroJudicial' ,"",""  , 0,"" }) //  2
   aadd(laTables,{' nr_sinistro ="'         ,"",""  , 3,"C"}) //  3
   aadd(laTables,{' nr_pasta ="'            ,"",""  , 4,"N"}) //  4
   aadd(laTables,{' dt_citacao ="'          ,"",""  , 5,"D"}) //  5  formato DD-MM-AAAA
   aadd(laTables,{' id_pessoa_autor = "'    ,"",""  , 6,"C"}) //  6
   aadd(laTables,{' nm_autor = "'           ,"",""  , 7,"C"}) //  7
   aadd(laTables,{' nr_cnpj_cpf_autor ="'   ,"",""  , 8,"C"}) //  8
   aadd(laTables,{' cd_uf ="'               ,"",""  , 9,"C"}) //  9
   aadd(laTables,{' nm_perda ="'            ,"",""  ,10,"C"}) // 10
   aadd(laTables,{' vl_economico ="'        ,"",""  ,11,"N"}) // 11
   aadd(laTables,{' vl_acao ="'             ,"",""  ,12,"N"}) // 12
   aadd(laTables,{' vl_pagamento ="'        ,"",""  ,13,"N"}) // 13
   aadd(laTables,{' nr_processo_judicial ="',"",""  ,14,"N"}) // 14
   aadd(laTables,{' nm_reclamante ="'       ,"",""  ,15,"C"}) // 15 
   aadd(laTables,{' id_motivo_judicial ="'  ,"",""  ,16,"C"}) // 16 
   aadd(laTables,{' nr_ramo ="'             ,"",""  ,17,"C"}) // 17 
   aadd(laTables,{' id_produto_cobertura ="',"",""  ,18,"C"}) // 18 
   * aadd(laTables,{' nm_cobertura ="'        ,"",""  ,19,"C"})   
   aadd(laTables,{' vl_atualizado_total = "',"","/>",19,"N"}) // 19
   aadd(laTables,{' vl_risco_calculado = "' ,"","/>",20,"N"}) // 20
   aadd(laTables,{' vl_correcao = "'        ,"","/>",21,"N"}) // 21
   aadd(laTables,{' vl_juros = "'           ,"","/>",22,"N"}) // 22
   aadd(laTables,{'</i4proerp>'             ,"",""  , 0,"" }) // 23
   *                      1                  2  3     4  5
              
   for ii:= 1 to len(laTables) 
   
      lxValue:= ""
      if laTables[ii,4] > 0
         lxValue:= faVals[laTables[ii,4]]
         if laTables[ii,5] == "C"
            if valtype(lxValue) == "C"
               lxValue:= alltrim(lxValue)
            elseif valtype(lxValue) == "N"
               lxValue:= alltrim(str(lxValue))
            endif
         elseif laTables[ii,5] == "D"
            lxValue:= dtoc(lxValue)
            lxValue:= strtran(lxValue,"/","-")
         elseif laTables[ii,5] == "N"
            if valtype(lxValue) == "N"
               lxValue:= alltrim(str(lxValue))
            else
               lxValue:= alltrim(lxValue)
            endif   
         else
            lxValue:= ""
         endif
         if empty(lxValue)
            lxValue:= ""
         endif   
         laTables[ii,2]:= lxValue
      endif
   
   next ii
      
   if fnXml > 0
      lcLine:= "" 
        
      for ii:= 1 to len(laTables)
      
         lcLine+= laTables[ii,1]
         if laTables[ii,4] > 0
            lcLine+= laTables[ii,2] + '"'
         endif
         if ! empty(laTables[ii,3])
            lcLine+= laTables[ii,3]
         endif
         
      next ii

      writeLine(fnXml,lcLine)
   
   endif   
   if ! llFlg
      dispMessage(pnHOcor,lcMess)
   endif
   plFlg:= llFlg
      
return (llFlg)
/*
* Function..: excluirArquivosXml()
* Objetive..: excluir os arquivos xml do diretório destino para gerar novamente novos arquivos
* Parameter.:
*   fcPath..: diretorio
*   fcFile..: arquivo
* Return....: .t./.f.
*   .t. processado com sucesso
*   .f. problemas no processamento
*/
function excluirArquivosXml(fcPath,fcFile)
   local llFlg      := .T. // as logical
   local ii         := 0   // as int
   local lcFile     := "",;
         lcMess     := ""  // as string
   local laFiles    := {},;
         laTemp     := {}  // as array
             
   lcMess:= "Excluindo os arquivos XML gerados anteriormente" 
   dispMessage(pnHOcor,lcMess) 
   
   lcFile:= fcPath + fcFile + "*.XML"    

   laTemp:= directory(lcFile)
   
   for ii:= 1 to len(laTemp)
   
      lcFile:= alltrim(laTemp[ii,1])
      aadd(laFiles,lcFile)
      
   next ii
   
   for ii:= 1 to len(laFiles)
   
      lcFile:= "rm " + fcPath + alltrim(laFiles[ii])
      lcMess:= space(3) + "Processando o comando: " + lcFile
      dispMessage(pnHOcor,lcMess)
      
      run(lcFile)
      
   next i
   
   if ! llFlg
      dispMessage(pnHOcor,lcMess)
   endif
   plFlg:= llFlg
      
return (llFlg)
/*
* Function..: getValorReserva()
* Objective.: obter o valor da reserva
* Parameters:
*   fxVal...: origem
*   fxRet...: destino
*   fnRes...: reserva
*   fnPasta.: nr_pasta
*   fnCont..: nr_controle da pasta_seguro
*   fnCal...: vl_risco_calc
*   fnCor...: vl_correcao
*   fnJur...: vl_juros
* Return....: nil  
*/
function getValorReserva(fxVal,fxRet,fnRes,fnPasta,fnCont,fnCal,fnCor,fnJur)
   local llFlg       := .T. // as logical
   local lcTabPedido := "pasta_pedidos",;
         lcColumn    := "",;
         lcMess      := ""  // as string
   local laCols      := {},;
         laWhere     := {},;
         laResult    := {}  // as array    

   lcColumn:= "CAST(SUM(" + lcTabPedido + ".VL_RISCO_CALC + " + lcTabPedido + ".VL_CORRECAO + " + lcTabPedido + ".VL_JUROS) AS NUMERIC(20,2))"
   aadd(laCols,lcColumn)
   lcColumn:= "CAST(SUM(" + lcTabPedido + ".VL_RISCO_CALC) AS NUMERIC(20,2))"
   aadd(laCols,lcColumn)
   lcColumn:= "CAST(SUM(" + lcTabPedido + ".VL_CORRECAO) AS NUMERIC(20,2))"
   aadd(laCols,lcColumn)
   lcColumn:= "CAST(SUM(" + lcTabPedido + ".VL_JUROS) AS NUMERIC(20,2))"
   aadd(laCols,lcColumn)
   
   * setando as variaveis de ambiente                                                                                                             
   wicSetCurVars(pnCurSet)   

   laWhere:= {}
   aadd(laWhere,lcTabPedido + ".NR_PASTA = " + alltrim(str(fnPasta)))
   aadd(laWhere,lcTabPedido + ".NR_CONTROLE_SEGURO = " + alltrim(str(fnCont)))
   
   lnError:= db_select(laCols,lcTabPedido, ,laWhere)
   if lnError == -1
      lcMess:= space(3) + "??? Problemas na pesquisa na tabela: " + lcTabPedido
      llFlg := .F.
   else
      laResult:= db_fetchrow()   
   endif
   
   fnCal:= 0
   fnCor:= 0
   fnJur:= 0
   if len(laResult) > 0
      fxRet:= laResult[1]
      fnCal:= laResult[2]
      fnCor:= laResult[3]
      fnJur:= laResult[4]
   else
      fxRet:= 0.00
   endif
   if ! llFlg
      dispMessage(pnHOcor,lcMess)
   endif
   plFlg:= llFlg
   fnRes:= fxRet

return (nil)
/*
* Function..: getCipFilialAtend()
* Objective.: obter o cip do CIP_FILIAL_ATEND
* Parameters:
*   fxVal...: origem
*   fxRet...: destino
*   fcCip...: cip
* Return....: nil  
*/
function getCipFilialAtend(fxVal,fxRet,fcCip)
   local llFlg       := .T. // as logical
   local lnError     := 0   // as int
   local lcTabPfpj   := "pasta_pfpj",;
         lcTipoPfpj  := "FIL",;
         lcNatureza  := "Juridica",;
         lcMess      := ""  // as string

   * setando variaveis de ambiente
   wicSetCurVars(pnCurSet)

   fxRet:= ""
   if ! empty(fxVal)
      if ! checkPfpj(fxVal,@fxRet,lcTipoPfpj,lcNatureza)
         lcMess:= space(3) + "??? Problemas na conferencia do pfpj"
         llFlg := .F.
      endif
   endif      
   if ! llFlg
      dispMessage(pnHOcor,lcMess)
   endif
   fcCip:= fxRet
   plFlg:= llFlg      
   
return (nil)
/*
* Function..: checkPfpj()
* Objective.: conferir e atualizar pfpj
* Parameters:
*   fcPfpj..: nome
*   fcCip...: cip
*   fcTipo..: tipo
*   fcNatu..: natureza
* Return....: .t./.f.
*   .t. processado com sucesso
*   .f. problemas no processamento
*/
function checkPfpj(fcPfpj,fcCip,fcTipo,fcNatu)
   local llFlg      := .T. // as logical
   local lnError    := 0,;
         lnPfpjCont := 0,;
         ii         := 0   // as int
   local lcTabPfpj  := "pfpj",;
         lcPfpjSeq  := "pfpj_nr_controle_seq",;
         lcChar     := "",;
         lcCip      := "",;
         lcMess     := ""  // as string
   local lxVal,;
         lxRet,;
         lbProc      
   local laCols     := {},;
         laStruPfpj := {},;
         laWhere    := {},;
         laVals     := {},;
         laValues   := {},;
         laResult   := {}  // as array

   aadd(laStruPfpj,{"NR_CONTROLE"    ,"N", 20,0}) 	
   aadd(laStruPfpj,{"PFPJ_NATUREZA"  ,"C",  8,0})	
   aadd(laStruPfpj,{"DT_CADASTRO"    ,"D",  8,0})	
   aadd(laStruPfpj,{"PFPJ"           ,"C", 90,0})     
   aadd(laStruPfpj,{"NM_FANTASIA"    ,"C", 45,0})               
   aadd(laStruPfpj,{"PFPJ_CHAR"      ,"C", 90,0})               
   aadd(laStruPfpj,{"PFPJ_TIPOS"     ,"C",200,0})               
   aadd(laStruPfpj,{"LOGIN_CADASTRO" ,"C", 25,0})      
   aadd(laStruPfpj,{"LOGIN_APROVACAO","C", 25,0})      
   aadd(laStruPfpj,{"DT_APROVACAO"   ,"D",  8,0})         
   aadd(laStruPfpj,{"FL_APROVADO"    ,"C",  1,0})            
   aadd(laStruPfpj,{"CIP"            ,"C", 20,0})               

   for ii:= 1 to len(laStruPfpj)
   
      aadd(laCols,laStruPfpj[ii,1])
      
   next ii
         
   * setando variaveis de ambiente
   wicSetCurVars(pnCurSet)
         
   if ! empty(fcPfpj) 
      fcPfpj:= alltrim(fcPfpj) 
       
      lcChar:= lower(alltrim(lat2char(fcPfpj)))

      laWhere:= {}
      aadd(laWhere,"PFPJ_CHAR = '" + lcChar + "'")
       
       lnError:= db_select(laCols,lcTabPfpj, ,laWhere)
       if lnError == -1
          lcMess:= space(3) + "??? Problemas na pesquisa na tabela: " + lcTabPfpj
          llFlg := .F.
       else
          laResult:= db_fetchrow()
          if len(laResult) > 0
             lcCip:= alltrim(str(laResult[1]))
          else
             * cadastrar o pfpj
             getNextAutoInc(lxVal,@lxRet,@lnPfpjCont,lcPfpjSeq)

             lcCip:= alltrim(str(lnPfpjCont))
          
             laVals:= {}
             aadd(laVals,lnPfpjCont)  // NR_CONTROLE     N  20,0 	
             aadd(laVals,fcNatu)      // PFPJ_NATUREZA   C   8,0	
             aadd(laVals,date())      // DT_CADASTRO     D   8,0	
             aadd(laVals,fcPfpj)      // PFPJ            C  90,0     
             aadd(laVals,fcPfpj)      // NM_FANTASIA     C  45,0               
             aadd(laVals,lcChar)      // PFPJ_CHAR       C  90,0               
             aadd(laVals,fcTipo)      // PFPJ_TIPOS      C 200,0               
             aadd(laVals,pcLgPadrao)  // LOGIN_CADASTRO  C  25,0      
             aadd(laVals,pcLgPadrao)  // LOGIN_APROVACAO C  25,0      
             aadd(laVals,date())      // DT_APROVACAO    D   8,0        
             aadd(laVals,"S")         // FL_APROVADO     C   1,0            
             aadd(laVals,lcCip)       // CIP             C  20,0               

             laValues:= {}
             aadd(laValues,laCols)
             aadd(laValues,laVals)
             *                      1        2      3 4 5 6
             lnError:= db_insert(laValues,lcTabPfpj, , , ,laStruPfpj)
             if lnError == -1
                lcMess:= space(3) + "??? Problemas na inclusao na tabela: " + lcTabPfpj
                llFlg := .F.
             endif
          endif
       endif
   endif
   if ! llFlg
      dispMessage(pnHOcor,lcMess)
   endif   
   fcCip := lcCip
   plFlg := llFlg

return (llFlg)
/*
* Function..: excPastaSeguroRelacionadas()
* Objective.: processar a exclusao de dados de tabelas relacionadas a pasta_seguro
* Parameters:
*   fnPasta.: nr_pasta
*   fnCont..: nr_controle
* Return....: .t./.f.
*   .t. processado com sucesso
*   .f. problemas no processamento
*/
* excluindo pasta_seguro_segurado, pasta_seguro_vitima, pasta_seguro_reclamante, pasta_seguro_lmi
function excPastaSeguroRelacionadas(fnPasta,fnCont)
   local llFlg       := .T. // as logical
   local lcMess      := ""  // as string
   local laTables    := {},;
         laWhere     := {}  // as array
         
   aadd(laTables,"pasta_seguro_segurado") 
   aadd(laTables,"pasta_seguro_vitima") 
   aadd(laTables,"pasta_seguro_reclamante") 
   aadd(laTables,"pasta_seguro_lmi") 
        
   if ! llFlg
      dispMessage(pnHOcor,lcMess)
   endif   
   plFlg := llFlg

return (llFlg)
/*
* Function..: getSeguroSegurado()
* Objective.: conferir e atualizar pasta_seguro_segurado
* Parameters:
*   fnPasta.: nr_pasta
*   fnCont..: nr_controle
*   fcCip...: cip
* Return....: nil  
*/
function getSeguroSegurado(fnPasta,fnCont,fcCip)
   local llFlg       := .T. // as logical
   local lnError     := 0,;
         ii          := 0   // as int
   local lcTabSeguro := "pasta_seguro_segurado",;
         lcMess      := ""  // as string
   local laStruSeguro:= {},;
         laCols      := {},;
         laWhere     := {},;
         laValues    := {},;
         laVals      := {},;
         laResult    := {}  // as array

   aadd(laStruSeguro,{"NR_PASTA"       ,"N", 20,0})
   aadd(laStruSeguro,{"NR_CONTROLE"    ,"N", 20,0})
   aadd(laStruSeguro,{"CIP_SEGURADO"   ,"C", 20,0})
   aadd(laStruSeguro,{"NR_CONTRATO"    ,"C", 20,0})
   
   for ii:= 1 to len(laStruSeguro)
   
      aadd(laCols,laStruSeguro[ii,1])
      
   next ii
   
   * setando variaveis de ambiente
   wicSetCurVars(pnCurSet)

   laWhere:= {}
   aadd(laWhere,"NR_PASTA = "      + alltrim(str(fnPasta)))
   aadd(laWhere,"NR_CONTROLE = "   + alltrim(str(fnCont)))
   aadd(laWhere,"CIP_SEGURADO = '" + alltrim(fcCip) + "'")
   
   lnError:= db_select(laCols,lcTabSeguro, ,laWhere)
   if lnError == -1
      lcMess:= space(3) + "??? Problemas na pesquisa na tabela: " + lcTabSeguro
      llFlg := .F.
   else
      laResult:= db_fetchrow() 
      if len(laResult) == 0
         laVals:= {}

         aadd(laVals,fnPasta) // NR_PASTA       N 20,0
         aadd(laVals,fnCont)  // NR_CONTROLE    N 20,0
         aadd(laVals,fcCip)   // CIP_SEGURADO   C 20,0
         aadd(laVals,"")      // NR_CONTRATO    C 20,0
         
         laValues:= {}
         aadd(laValues,laCols)
         aadd(laValues,laVals)
         *                       1         2      3 4 5 6
         lnError:= db_insert(laValues,lcTabSeguro, , , ,laStruSeguro)
         if lnError == -1
            lcMess:= space(3) + "??? Problemas na inclusao na tabela: " + lcTabSeguro
            llFlg := .F.
         endif
      endif  
   endif
   if ! llFlg
      dispMessage(pnHOcor,lcMess)
   endif
   plFlg:= llFlg
             
return (llFlg)
/*
* Function..: getSeguroVitima()
* Objective.: conferir e atualizar pasta_seguro_vitima
* Parameters:
*   fnPasta.: nr_pasta
*   fnCont..: nr_controle
*   fcCip...: cip
* Return....: nil  
*/
function getSeguroVitima(fnPasta,fnCont,fcCip)
   local llFlg       := .T. // as logical
   local lnError     := 0,;
         ii          := 0   // as int
   local lcTabVitima := "pasta_seguro_vitima",;
         lcMess      := ""  // as string
   local laStruVitima:= {},;
         laCols      := {},;
         laWhere     := {},;
         laValues    := {},;
         laVals      := {},;
         laResult    := {}  // as array

   aadd(laStruVitima,{"NR_PASTA"           ,"N", 20,0})
   aadd(laStruVitima,{"NR_CONTROLE"        ,"N", 20,0})
   aadd(laStruVitima,{"CIP_VITIMA"         ,"C", 20,0})
   aadd(laStruVitima,{"NR_COBERTURA_VITIMA","N", 20,0})
   aadd(laStruVitima,{"VL_RESERVA3"        ,"N", 20,0})
   
   for ii:= 1 to len(laStruVitima)
   
      aadd(laCols,laStruVitima[ii,1])
      
   next ii
   
   * setando variaveis de ambiente
   wicSetCurVars(pnCurSet)

   laWhere:= {}
   aadd(laWhere,"NR_PASTA = "    + alltrim(str(fnPasta)))
   aadd(laWhere,"NR_CONTROLE = " + alltrim(str(fnCont)))
   aadd(laWhere,"CIP_VITIMA = '" + alltrim(fcCip) + "'")
   
   lnError:= db_select(laCols,lcTabVitima, ,laWhere)
   if lnError == -1
      lcMess:= space(3) + "??? Problemas na pesquisa na tabela: " + lcTabVitima
      llFlg := .F.
   else
      laResult:= db_fetchrow() 
      if len(laResult) == 0
         laVals:= {}

         aadd(laVals,fnPasta) // NR_PASTA             N 20,0
         aadd(laVals,fnCont)  // NR_CONTROLE          N 20,0
         aadd(laVals,fcCip)   // CIP_VITIMA           C 20,0
         aadd(laVals,0)       // NM_COBERTURA_VITIMA  N 20,0
         aadd(laVals,0)       // VL_RESERVA3          N 20,0
         
         laValues:= {}
         aadd(laValues,laCols)
         aadd(laValues,laVals)
         *                       1         2      3 4 5 6
         lnError:= db_insert(laValues,lcTabVitima, , , ,laStruVitima)
         if lnError == -1
            lcMess:= space(3) + "??? Problemas na inclusao na tabela: " + lcTabVitima
            llFlg := .F.
         endif
      endif  
   endif
   if ! llFlg
      dispMessage(pnHOcor,lcMess)
   endif
   plFlg:= llFlg
             
return (llFlg)
/*
* Function..: getSeguroReclamante()
* Objective.: conferir e atualizar pasta_seguro_reclamante
* Parameters:
*   fnPasta.: nr_pasta
*   fnCont..: nr_controle
*   fcCip...: cip
* Return....: nil  
*/
function getSeguroReclamante(fnPasta,fnCont,fcCip)
   local llFlg       := .T. // as logical
   local lnError     := 0,;
         ii          := 0   // as int
   local lcTabReclama:= "pasta_seguro_reclamante",;
         lcMess      := ""  // as string
   local laStruVitima:= {},;
         laCols      := {},;
         laWhere     := {},;
         laValues    := {},;
         laVals      := {},;
         laResult    := {}  // as array

   aadd(laStruReclama,{"NR_PASTA"           ,"N", 20,0})
   aadd(laStruReclama,{"NR_CONTROLE"        ,"N", 20,0})
   aadd(laStruReclama,{"CIP_RECLAMANTE"     ,"C", 20,0})
   
   for ii:= 1 to len(laStruReclama)
   
      aadd(laCols,laStruReclama[ii,1])
      
   next ii
   
   * setando variaveis de ambiente
   wicSetCurVars(pnCurSet)

   laWhere:= {}
   aadd(laWhere,"NR_PASTA = "        + alltrim(str(fnPasta)))
   aadd(laWhere,"NR_CONTROLE = "     + alltrim(str(fnCont)))
   aadd(laWhere,"CIP_RECLAMANTE = '" + alltrim(fcCip) + "'")
   
   lnError:= db_select(laCols,lcTabReclama, ,laWhere)
   if lnError == -1
      lcMess:= space(3) + "??? Problemas na pesquisa na tabela: " + lcTabReclama
      llFlg := .F.
   else
      laResult:= db_fetchrow() 
      if len(laResult) == 0
         laVals:= {}

         aadd(laVals,fnPasta) // NR_PASTA             N 20,0
         aadd(laVals,fnCont)  // NR_CONTROLE          N 20,0
         aadd(laVals,fcCip)   // CIP_RECLAMANTE       C 20,0
         
         laValues:= {}
         aadd(laValues,laCols)
         aadd(laValues,laVals)
         *                       1         2      3 4 5 6
         lnError:= db_insert(laValues,lcTabReclama, , , ,laStruReclama)
         if lnError == -1
            lcMess:= space(3) + "??? Problemas na inclusao na tabela: " + lcTabReclama
            llFlg := .F.
         endif
      endif  
   endif
   if ! llFlg
      dispMessage(pnHOcor,lcMess)
   endif
   plFlg:= llFlg
             
return (llFlg)
/*
* Function..: getSeguroCausaNis()
* Objective.: conferir e atualizar a tabela segurocausanis
* Parameters:
*   fxVal...: origem
*   fxRet...: destino
*   fnNis...: cd_causa_nis
* Return....: nil  
*/
function getSeguroCausaNis(fxVal,fxRet,fnNis)
   local llFlg       := .T. // as logical
   local lnError     := 0,;
         ii          := 0   // as int
   local lcTabSegNis := "segurocausanis",;
         lcMess      := ""  // as string
   local laStruSegNis:= {},;
         laCols      := {},;
         laWhere     := {},;
         laValues    := {},;
         laVals      := {},;
         laResult    := {}  // as array    

   
   aadd(laStruSegNis,{"CD_CAUSA_NIS","N", 20, 0})
   aadd(laStruSegNis,{"NM_CAUSA_NIS","C", 30, 0})
   aadd(laStruSegNis,{"FL_ATIVO"    ,"C",  1, 0})
   
   for ii:= 1 to len(laStruSegNis)
   
      aadd(laCols,laStruSegNis[ii,1])
      
   next ii

   * setando variaveis de ambiente
   wicSetCurVars(pnCurSet)

   if ! empty(fnNis)
      laWhere:= {}
      aadd(laWhere,"CD_CAUSA_NIS = " + alltrim(str(fnNis)))
      
      lnError:= db_select(laCols,lcTabSegNis, ,laWhere)
      if lnError == -1
         lcMess:= space(3) + "??? Problemas na pesquisa na tabela: " + lcTabSegNis
         llFlg := .F.
      else
         laResult:= db_fetchrow() 
         if len(laResult) == 0
         
            laVals:= {}
            aadd(laVals,fnNis         ) // CD_CAUSA_NIS N 20 0
            aadd(laVals,alltrim(fxVal)) // NM_CAUSA_NIS C 30 0
            aadd(laVals,"S")            // FL_ATIVO     C  1 0
            
            laValues:= {}
            aadd(laValues,laCols)
            aadd(laValues,laVals)
            *                     1          2       3 4 5 6
            lnError:= db_insert(laValues,lcTabSegNis, , , ,laStruSegNis)
            if lnError == -1
               lcMess:= space(3) + "??? Problemas na inclusao na tabela: " + lcTabSegNis
               llFlg := .F.
            endif
         endif 
      endif
   endif
   if llFlg
      dispMessage(pnHOcor,lcMess)
   endif
   plFlg:= llFlg
   
return (nil)
/*
* Function..: chekTipoSinistro()
* Objective.: conferir e atualizar a tabela tipo_sinistro
* Parameters:
*   fxVal...: origem
*   fxRet...: destino
* Return....: nil  
*/
function chekTipoSinistro(fxVal,fxRet)
   local llFlg       := .T. // as logical
   local lnError     := 0,;
         ii          := 0   // as int
   local lcTabTipo   := "tipo_sinistro",;
         lcMess      := ""  // as string
   local laStruTipo  := {},;
         laCols      := {},;
         laWhere     := {},;
         laValues    := {},;
         laVals      := {},;
         laResult    := {}  // as array    

   
   aadd(laStruTipo,{"TP_SINISTRO" ,"C", 30, 0})
   aadd(laStruTipo,{"FL_ATIVO"    ,"C",  1, 0})
   
   for ii:= 1 to len(laStruTipo)
   
      aadd(laCols,laStruTipo[ii,1])
      
   next ii

   * setando variaveis de ambiente
   wicSetCurVars(pnCurSet)

   if ! empty(fxVal)
      fxVal:= alltrim(fxVal)
      
      if len(fxVal) > 30
         fxVal:= alltrim(substr(fxVal,1,30))
      endif
      
      laWhere:= {}
      aadd(laWhere,"TP_SINISTRO = '" + alltrim(fxVal) + "'")
      
      lnError:= db_select(laCols,lcTabTipo, ,laWhere)
      if lnError == -1
         lcMess:= space(3) + "??? Problemas na pesquisa na tabela: " + lcTabTipo
         llFlg := .F.
      else
         laResult:= db_fetchrow() 
         if len(laResult) == 0
         
            laVals:= {}
            aadd(laVals,fxVal) // TP_SINISTRO  C 30 0
            aadd(laVals,"S"  ) // FL_ATIVO     C  1 0
            
            laValues:= {}
            aadd(laValues,laCols)
            aadd(laValues,laVals)
            *                     1          2     3 4 5 6
            lnError:= db_insert(laValues,lcTabTipo, , , ,laStruTipo)
            if lnError == -1
               lcMess:= space(3) + "??? Problemas na inclusao na tabela: " + lcTabTipo
               llFlg := .F.
            endif
         endif 
      endif
   endif
   if llFlg
      dispMessage(pnHOcor,lcMess)
   endif
   fxRet:= fxVal
   plFlg:= llFlg
      
return (nil)
/*
* Function..: checkSeguroLmi()
* Objective.: conferir e atualizar a tabela pasta_seguro_lmi
* Parameters:
*   fnPasta.: nr_pasta
*   fnCont..: nr_controle
*   fcDesc..: lmi_nm_cobertura
*   fnVlLmi.: vl_is
*   fnVlSini: vl_aviso
* Return....: nil  
*/
function checkSeguroLmi(fnPasta,fnCont,fcDesc,fnVlLmi,fnVlSini)
   local llFlg       := .T. // as logical
   local lnError     := 0,;
         lnNrLmi     := 0,;
         ii          := 0   // as int
   local lcTabSegLmi := "pasta_seguro_lmi",;
         lcSegSegLmi := "pasta_seguro_lmi_nr_lmi_seq",;
         lcMess      := ""  // as string
   local laStruSegLmi:= {},;
         laCols      := {},;
         laWhere     := {},;
         laResult    := {} // as array
                 
   aadd(laStruSegLmi,{"NR_PASTA"          ,"N", 20,0})
   aadd(laStruSegLmi,{"NR_CONTROLE"       ,"N", 20,0})
   aadd(laStruSegLmi,{"LMI_VL"            ,"N", 20,2})
   aadd(laStruSegLmi,{"LMI_VL_SINISTRADO" ,"N", 20,2})
   aadd(laStruSegLmi,{"LMI_NM_COBERTURA"  ,"C",200,0})

   for ii:= 1 to len(laStruSegLmi) 
   
      aadd(laCols,laStruSegLmi[ii,1])
      
   next ii
            
   * setando variaveis de ambiente
   wicSetCurVars(pnCurSet)

*   if ! empty(fcDesc)
      fcDesc:= alltrim(fcDesc)
      aadd(laWhere,"NR_PASTA = "          + alltrim(str(fnPasta)))
      aadd(laWhere,"NR_CONTROLE = "       + alltrim(str(fnCont)))
      aadd(laWhere,"LMI_NM_COBERTURA = '" + alltrim(fcDesc) + "'")
         
      lnError:= db_select(laCols,lcTabSegLmi, ,laWhere)
      if lnError == -1
         lcMess:= space(3) + "??? Problemas na pesquisa na tabela: " + lcTabSegLmi
         llFlg := .F.
      else
         laResult:= db_fetchrow() 
         if len(laResult) == 0
            laVals:= {}
            aadd(laVals,fnPasta)  // NR_PASTA          N  20,0
            aadd(laVals,fnCont)   // NR_CONTROLE       N  20,0
            aadd(laVals,fnVlLmi)  // LMI_VL            N  20,2
            aadd(laVals,fnVlSini) // LMI_VL_SINISTRADO N  20,2
            aadd(laVals,fcDesc)   // LMI_NM_COBERTURA  C 200,0
               
            laValues:= {}
            aadd(laValues,laCols)
            aadd(laValues,laVals)
            *                      1          2      3 4 5 6
            lnError:= db_insert(laValues,lcTabSegLmi, , ,laStruSegLmi)
            if lnError == -1
               lcMess:= space(3) + "??? Problemas na inclusao na tabela: " + lcTabSegLmi
               llFlg := .F.
            endif  
         endif
      endif
*   endif
   if ! llFlg
      dispMessage(pnHOcor,lcMess)
   endif

   plFlg:= llFlg

return (llFlg)
/*
* Function..: chekRamoSrSn()
* Objective.: conferir e fazer a manutençao da tabela ramosrsn
* Parameters:
*   fxVal...: origem
*   fxRet...: destino
* Return....: nil  
*/
function chekRamoSrSn(fxVal,fxRet)
   local llFlg       := .T. // as logical
   local lnError     := 0,;
         ii          := 0   // as int
   local lcTabRamoSr := "ramosrsn",;
         lcMess      := ""  // as string
   local laStruRamo  := {},;
         laCols      := {},;
         laWhere     := {},;
         laResult    := {} // as array
                 
   aadd(laStruRamo,{"CD_RAMOSRSN"   ,"C" ,  7,0})
   aadd(laStruRamo,{"SEGURORAMO"    ,"C" , 30,0})
   aadd(laStruRamo,{"SEGUROPRODUTO" ,"C" , 30,0})
   aadd(laStruRamo,{"SEGUROPROFIT"  ,"C" , 30,0})
   aadd(laStruRamo,{"FL_ATIVO"      ,"C" ,  1,0})

   for ii:= 1 to len(laStruRamo) 
   
      aadd(laCols,laStruRamo[ii,1])
      
   next ii
            
   * setando variaveis de ambiente
   wicSetCurVars(pnCurSet)

   if ! empty(fxVal)
      fxVal:= alltrim(fxVal)
      
      if len(fxVal) > 7
         fxVal:= alltrim(substr(fxVal,1,7))
      endif   
      aadd(laWhere,"CD_RAMOSRSN = '" + fxVal + "'")
         
      lnError:= db_select(laCols,lcTabRamoSr, ,laWhere)
      if lnError == -1
         lcMess:= space(3) + "??? Problemas na pesquisa na tabela: " + lcTabRamoSr
         llFlg := .F.
      else
         laResult:= db_fetchrow() 
         if len(laResult) == 0
            laVals:= {}
            aadd(laVals,fxVal              ) // CD_RAMOSRSN   C  7,0
            aadd(laVals,"Seguro: "  + fxVal) // SEGURORAMO    C 30,0
            aadd(laVals,"Pruduto: " + fxVal) // SEGUROPRODUTO C 30,0
            aadd(laVals,"Profit: "  + fxVal) // SEGUROPROFIT  C 30,0
            aadd(laVals,"S"                ) // FL_ATIVO      C  1,0
             
            laValues:= {}
            aadd(laValues,laCols)
            aadd(laValues,laVals)
            *                      1          2      3 4 5 6
            lnError:= db_insert(laValues,lcTabRamoSr, , , ,laStruRamo)
            if lnError == -1
               lcMess:= space(3) + "??? Problemas na inclusao na tabela: " + lcTabRamoSr
               llFlg := .F.
            endif
         endif
      endif
   endif
   if ! llFlg
      dispMessage(pnHOcor,lcMess)
   endif
   fxRet:= fxVal
   plFlg:= llFlg

return (nil)
/*
* Function..: chekSinistroStatus()
* Objective.: conferir e atualizar a tabela sinistro_status
* Parameters:
*   fxVal...: origem
*   fxRet...: destino
* Return....: nil  
*/
function chekSinistroStatus(fxVal,fxRet)
   local llFlg       := .T. // as logical
   local lnError     := 0,;
         ii          := 0   // as int
   local lcTabStatus := "sinistro_status",;
         lcMess      := ""  // as string
   local laStruStatus:= {},;
         laCols      := {},;
         laWhere     := {},;
         laResult    := {} // as array
         
   aadd(laStruStatus,{"FL_SINISTRO", "C", 10,0}) 
   aadd(laStruStatus,{"FL_ATIVO"   , "C",  1,0}) 
   
   for ii:= 1 to len(laStruStatus) 
   
      aadd(laCols,laStruStatus[ii,1])
      
   next ii
            
   * setando variaveis de ambiente
   wicSetCurVars(pnCurSet)
   if ! empty(fxVal)
      fxVal:= alltrim(fxVal)
      
      if len(fxVal) > 10
         fxVal:= alltrim(substr(fxVal,1,10))
      endif   
      laWhere:= {}
      aadd(laWhere,"FL_SINISTRO = '" + fxVal + "'")
         
      lnError:= db_select(laCols,lcTabStatus, ,laWhere)
      if lnError == -1
         lcMess:= space(3) + "??? Problemas na pesquisa na tabela: " + lcTabStatus
         llFlg := .F.
      else
         laResult:= db_fetchrow() 
         if len(laResult) == 0
            laVals:= {}
            aadd(laVals,fxVal) // FL_SINISTRO
            aadd(laVals,"S")   // FL_ATIVO
               
            laValues:= {}
            aadd(laValues,laCols)
            aadd(laValues,laVals)
            *                      1          2      3 4 5 6
            lnError:= db_insert(laValues,lcTabStatus, , , ,laStruStatus)
            if lnError == -1
               lcMess:= space(3) + "??? Problemas na inclusao na tabela: " + lcTabStatus
               llFlg := .F.
            endif  
         endif
      endif
   endif
   if ! llFlg
      dispMessage(pnHOcor,lcMess)
   endif
   fxRet:= fxVal
   plFlg:= llFlg
   
return (nil)
/*
* Function..: getCipPfpj()
* Objective.: conferir e atualizar a tabela pfpj
* Parameters:
*   fxVal...: origem
*   fxRet...: destino
*   fcCip...: cip
*   fcCnpj..: cnpj_cpf
* Return....: nil  
*/
function getCipPfpj(fxVal,fxRet,fcCip,fcCnPj)
   local llFlg       := .T. // as logical
   local lcTabPfpj   := "pfpj",;
         lcTipo      := "SEG",;
         lcNatureza  := "fisica",;
         lcMess      := ""  // as string
   local laCols      := {},;
         laWhere     := {},;
         laValues    := {},;
         laVals      := {},;
         laResult    := {}  // as string
           
   * setando variaveis de ambiente
   wicSetCurVars(pnCurSet)
   
   fxRet:= ""
   fcCip:= ""   
   if ! empty(fxVal)
      if ! checkPfpjCadastro(fxVal,@fcCip,lcTipo,lcNatureza,fcCnpj)
         lcMess:= space(3) + "??? Problemas na conferencia e atualizaçao da tabela: " + lcTabPfpj
         llFlg := .F.
      endif
   else
      fxRet:= ""
      fcCip:= ""   
   endif
   if ! llFlg
      dispMessage(pnHOcor,lcMess)
   endif
   fxRet:= fcCip
   plFlg:= llFlg
   
return (nil)
/*
* Function..: checkPfpjCadastro()
* Objective.: conferir e atualizar pfpj
* Parameters:
*   fcPfpj..: nome
*   fcCip...: cip
*   fcTipo..: tipo
*   fcNatu..: natureza
*   fcCnpj..: cnpj_cpf
* Return....: .t./.f.
*   .t. processado com sucesso
*   .f. problemas no processamento
*/
function checkPfpjCadastro(fcPfpj,fcCip,fcTipo,fcNatu,fcCnpj)
   local llFlg      := .T. // as logical
   local lnError    := 0,;
         lnPfpjCont := 0,;
         ii         := 0   // as int
   local lcTabPfpj  := "pfpj",;
         lcPfpjSeq  := "pfpj_nr_controle_seq",;
         lcChar     := "",;
         lcCip      := "",;
         lcMess     := ""  // as string
   local lxVal,;
         lxRet,;
         lbProc      
   local laCols     := {},;
         laUCols    := {},;
         laStruPfpj := {},;
         laStrUpdate:= {},;
         laWhere    := {},;
         laVals     := {},;
         laValues   := {},;
         laResult   := {}  // as array

   aadd(laStruPfpj,{"NR_CONTROLE"    ,"N", 20,0}) 	
   aadd(laStruPfpj,{"PFPJ_NATUREZA"  ,"C",  8,0})	
   aadd(laStruPfpj,{"DT_CADASTRO"    ,"D",  8,0})	
   aadd(laStruPfpj,{"PFPJ"           ,"C", 90,0})     
   aadd(laStruPfpj,{"CNPJ_CPF"       ,"C", 15,0})     
   aadd(laStruPfpj,{"NM_FANTASIA"    ,"C", 45,0})               
   aadd(laStruPfpj,{"PFPJ_CHAR"      ,"C", 90,0})               
   aadd(laStruPfpj,{"PFPJ_TIPOS"     ,"C",200,0})               
   aadd(laStruPfpj,{"LOGIN_CADASTRO" ,"C", 25,0})      
   aadd(laStruPfpj,{"LOGIN_APROVACAO","C", 25,0})      
   aadd(laStruPfpj,{"DT_APROVACAO"   ,"D",  8,0})         
   aadd(laStruPfpj,{"FL_APROVADO"    ,"C",  1,0})            
   aadd(laStruPfpj,{"CIP"            ,"C", 20,0})               

   for ii:= 1 to len(laStruPfpj)
   
      aadd(laCols,laStruPfpj[ii,1])
      
   next ii

   aadd(laStrUpdate,{"CNPJ_CPF"     ,"C", 15,0})
   
   for ii:= 1 to len(laStrUpdate)
         
      aadd(laUCols,laStrUpdate[ii,1])
      
   next ii
         
   * setando variaveis de ambiente
   wicSetCurVars(pnCurSet)
         
   if ! empty(fcPfpj) 
      fcPfpj:= alltrim(fcPfpj) 
       
      lcChar:= lower(alltrim(lat2char(fcPfpj)))

      laWhere:= {}
      aadd(laWhere,"PFPJ_CHAR = '" + lcChar + "'")
       
       lnError:= db_select(laCols,lcTabPfpj, ,laWhere)
       if lnError == -1
          lcMess:= space(3) + "??? Problemas na pesquisa na tabela: " + lcTabPfpj
          llFlg := .F.
       else
          laResult:= db_fetchrow()
          if len(laResult) > 0
             lcCip:= alltrim(str(laResult[1]))
             if ! empty(fcCnpj)
                laVals:= {}
                aadd(laVals,fcCnpj)
                
                laValues:= {}
                aadd(laValues,laUCols)
                aadd(laValues,laVals)
                
                laWhere:= {}
                aadd(laWhere,"NR_CONTROLE = " + lcCip)
                *                       1        2       3     4 5 6 7
                lnError:= db_update(laValues,lcTabPfpj,laWhere, , , ,laStrUpdate)
                if lnError == -1
                   lcMess:= space(3) + "??? Problemas na atualizaçao na tabela: " + lcTabPfpj
                   llFlg := .F.
                endif
             endif
          else
             * cadastrar o pfpj
             getNextAutoInc(lxVal,@lxRet,@lnPfpjCont,lcPfpjSeq)

             lcCip:= alltrim(str(lnPfpjCont))
          
             laVals:= {}
             aadd(laVals,lnPfpjCont)  // NR_CONTROLE     N  20,0 	
             aadd(laVals,fcNatu)      // PFPJ_NATUREZA   C   8,0	
             aadd(laVals,date())      // DT_CADASTRO     D   8,0	
             aadd(laVals,fcPfpj)      // PFPJ            C  90,0     
             aadd(laVals,fcCnpj)      // CNPJ_CPF        C  15,0     
             aadd(laVals,fcPfpj)      // NM_FANTASIA     C  45,0               
             aadd(laVals,lcChar)      // PFPJ_CHAR       C  90,0               
             aadd(laVals,fcTipo)      // PFPJ_TIPOS      C 200,0               
             aadd(laVals,pcLgPadrao)  // LOGIN_CADASTRO  C  25,0      
             aadd(laVals,pcLgPadrao)  // LOGIN_APROVACAO C  25,0      
             aadd(laVals,date())      // DT_APROVACAO    D   8,0        
             aadd(laVals,"S")         // FL_APROVADO     C   1,0            
             aadd(laVals,lcCip)       // CIP             C  20,0               

             laValues:= {}
             aadd(laValues,laCols)
             aadd(laValues,laVals)
             *                      1        2      3 4 5 6
             lnError:= db_insert(laValues,lcTabPfpj, , , ,laStruPfpj)
             if lnError == -1
                lcMess:= space(3) + "??? Problemas na inclusao na tabela: " + lcTabPfpj
                llFlg := .F.
             endif
          endif
       endif
   endif
   if ! llFlg
      dispMessage(pnHOcor,lcMess)
   endif   
   fcCip := lcCip
   plFlg := llFlg

return (llFlg)
/*
* Function..: getNrFenaseg()
* Objective.: obter o codigo do NR_SINISTRO_FENASEG
* Parameters:
*   fxVal...: origem
*   fxRet...: destino
* Return....: nil
* Comments..:
* nm_retorno: Sinistro já é judicial><SinistroJudicialCoberturas id_produto_cobertura=2110
*/
function getNrFenaseg(fxVal,fxRet)
   local xx    := 0 // as int

   if ! empty(fxVal)
      fxVal:= alltrim(fxVal)
   else
      fxVal:= ""   
   endif
   fxRet:= fxVal

return (nil)
/*
* Function..: getAtualizaUF()
* Objective.: verificar e atualizar o de/para de UF
* Parameters:
*   fxVal...: origem
*   fxRet...: destino
* Return....: nil  
*/
function getAtualizaUF(fxVal,fxRet)

   if ! empty(fxVal)
      if alltrim(fxVal) == "0"
         fxVal:= ""
      endif
   else
      fxVal:= ""
   endif
   fxRet:= fxVal
   
return (nil)
/*
* Function..: getVariavel()
* Objective.: retornar o valor da variavel
* Parameters:
*   fxVal...: origem
*   fxRet...: destino
*   fxVar...: variavel
* Return....: nil  
*/
function getVariavel(fxVal,fxRet,fxVar)

   if ! empty(fxVal)
      if valtype(fxVal) == "C"
         fxRet:= alltrim(fxVal)
      endif
   endif
   fxRet:= fxVal
   fxVar:= fxRet

return (nil)
/*
* Function..: getRiscoPerda()
* Objective.: obter o valor em maisculo sem sinal
* Parameters:
*   fxVal...: origem
*   fxRet...: destino
*   fcRisco.: riscoperda
* Return....: nil  
*/
function getRiscoPerda(fxVal,fxRet,fcRisco)

   if ! empty(fxVal)
      if valtype(fxVal) == "C"
         fxVal:= upper(alltrim(lat2char(fxVal)))
      endif
   endif
   fxRet  := fxVal
   fcRisco:= fxRet
   
return (nil)
/*
* Function..: getString2Date()
* Ojective..: converter string em formato data
* Parameters:
*   fxVal...: origem
*   fxRet...: destino
*   fdDat...: data
* Return....: nil  
* Comments..:
*   "24/11/2003"
*/
function getString2Date(fxVal,fxRet,fdDat)
   local ldData    := ctod("  /  /    ") // as data
   local lcData    := "" // as string

   fxRet:= ldData
   if ! empty(fxVal)
      ldData:= ctod(fxVal)
   endif
   fxRet:= ldData
   fdDat:= fxRet

return (nil)
/*
* Function..: getString2Numeric()
* Objective.: converter string em formato numerico
* Parameters:
*   fxVal...: origem
*   fxRet...: destino
*   fnVal...: valor
* Return....: nil  
* Comments..:
*   128971.40
*/
function getString2Numeric(fxVal,fxRet,fnNum)

   if ! empty(fxVal)
      fxRet:= val(fxVal)
   else
      fxRet:= 0
   endif
   fnNum:= fxRet
   
return (nil)
/*
* Function..: getFlCosseguro()
* Objective.: obter o codigo de cosseguro
* Parameters:
*   fxVal...: origem
*   fxRet...: destino
*   fcFl....: codigo cosseguro
* Return....: nil  
*/
function getFlCosseguro(fxVal,fxRet,fcFl)

   if empty(fxVal) 
      if fxVal == "0"
         fxRet:= "Y"
      else
         fxRet:= ""
      endif   
   else
      fxRet:= "Y"
   endif
   fcFl := fxRet
   
return (nil) 
/*
* Function..: getFlResseguro()
* Objective.: obter o codigo de resseguro
* Parameters:
*   fxVal...: origem
*   fxRet...: destino
*   fcFl....: codigo de resseguro
*/
function getFlResseguro(fxVal,fxRet,fcFl)

   if empty(fxVal)
      if fxVal == "0"
         fxRet:= "Y"
      else
         fxRet:= ""
      endif   
   else
      fxRet:= "Y"
   endif
   fcFl:= fxRet

return (nil)
/*
* Function..: getValorVariavel()
* Objective.: obter o valor da variavel
* Parameters:
*   fxVal...: origem
*   fxRet...: destino
*   fxVar...: variavel
* Return....: nil  
*/
function getValorVariavel(fxVal,fxRet,fxVar)

   fxRet:= fxVar

return (nil)
/*
* Function..: getPastaUf()
* Objective.: retornar vazio
* Parameters:
*   fxVal...: origem
*   fxRet...: destino
*   fcUf....: UF
* Return....: nil  
*/
function getPastaUf(fxVal,fxRet,fcUf)

   fxRet:= ""
   fcUf := ""
   
return (nil)
/*
* Function..: getSomenteNumeros()
* Objective.: retirar caracteres e retornar somente numeros
* Parameters:
*   fxVal...: origem
*   fxRet...: destino
*   fcVar...: variavel
* Return....: nil  
*/
function getSomenteNumeros(fxVal,fxRet,fcVar)
   local ii     := 0  // as int
   local lcChar := "" // as string
   
   if ! empty(fxVal)
      fxVal:= alltrim(fxVal)
   else
      fxVal:= ""
   endif
   
   for ii:= 1 to len(fxVal)

      if asc(substr(fxVal,ii,1)) > 47 .and.;
         asc(substr(fxVal,ii,1)) < 58
         lcChar+= substr(fxVal,ii,1)
      endif
         
   next ii
   
   fxRet:= lcChar
   fcVar:= fxRet
   
return (nil)

# include "/home/inso/library/prg/commons.prg"
# include "/home/inso/library/prg/auxiliar.prg"                                                                                     
# include "/home/inso/library/prg/xhbutils.prg"                                                                                     
# include "/home/inso/library/prg/wiclibs.prg"                                                                                      
# include "/home/inso/library/prg/errorsys.prg"                                                                                     
             