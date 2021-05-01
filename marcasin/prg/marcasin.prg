/*
* Program...: marcasin.prg
*/

# define NEWLINE chr(10)
# define EOF chr(26)

function main()
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
         lcVersao   := "Versao: prudential_marcasin_isj_10/12/2019 - 14:10",; // deve-se alterar a data a cada envio
         lcOBJ1     := "",; // handle para a conexao com banco origem
         lcOBJ2     := "",; // handle para a conexao com banco destino
         lcTabSeqInt:= "seq_interfaces",;
         lcProgram  := "Interface_marcasin",;
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
         lcHrNula   := "",;
         lcVal      := "",;
         lcStatus   := "",;
         lcPatFil   := "",;
         lcFile     := "",;
         lcLogFil   := "",;
         lcMess     := "" // as string
   local laCabLog   := {space(10) + "Ocorrencias de processamento de interface MarcaSin - ISJ",;
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
   public pcLogin    := "interface.marcasin"
   public pcProgram  := lcProgram
   public pcSysError := ""
   public pdDtInicio := date() 
   public pcHrInicio := time()
   public pdDtTermino:= date() 
   public pcHrTermino:= time()
   public paExporta  := {}
   
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
      lcFile  := alltrim(wicGetSetEnvs(pnCurSet,"LOGFILE")) + "interface_marcasin_" + strzero(year(date()),4) + strzero(month(date()),2) + strzero(day(date()),2) + ".log"
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
      if ! processaMarcaSin()
         lcMess:= "??? Problemas no processamento de MarcaSin"
         llFlg := .F.
      endif
   endif

   if llFlg
      lcMess:= "Interface MarcaSin processado com SUCESSO"
      dispMessage(lnHOcor,lcMess)
   endif

   dispMessage(lnHOcor,"")
   pdDtTermino:= date()
   pcHrTermino:= time()                                                                                          
   lcMess:= "Data Termino: " + dtoc(pdDtTermino) + " - Hora: " + pcHrTermino
   dispMessage(lnHOcor,lcMess)
   * calculando o tempo de processamento
   lcTempoProc:= calcIntervaloTempo(pdDtInicio,pcHrInicio,pdDtTermino,pcHrTermino)   
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
      RUN("rm " + lcErrorFile)   
      * RUN("rm " + lcLogFil )
   endif
   * RUN("DEL " + lcFileLog)
   ? ""
   if lnHDespFile > 0
      fclose(lnHDespFile)
   endif

return (nil)
/*
* Function..: processaMarcaSin()
* Objective.: processar MarcaSin
* Parameters:
*   nenhum
* Return....: .t./.f.
*   .t. processado com sucesso
*   .f. problemas no processamento
*/
function processaMarcaSin()
   local llFlg        := .T. // as logical
   local lnMaxRow     := 1000,;
         lnRefRow     := lnMaxRow,;
         lnCurRow     := 0,;
         lnRecoun     := 0,;
         lnNrPasta    := 0,;
         ii           := 0,;
         nn           := 0   // as int
   local lxVal,;
         lxRet,;
         lbProc
   local lcTabPasta   := "pasta",;
         lcTabSeguro  := "pasta_seguro",;
         lcColumn     := "",;
         lcFlPasta    := "",;
         lcTpPasta    := "",;
         lcNrSinistro := "",;
         lcMess       := ""  // as string
   local laTables     := {},;
         laCols       := {},;
         laJoin       := {},;
         laWhere      := {},;
         laOrder      := {},;
         laResult     := {} // as array
         
   aadd(laTables,{  1 , lcTabPasta  , "NR_PASTA"    , {|| getVariavel(lxVal,@lxRet,@lnNrPasta)    }})
   aadd(laTables,{  2 , lcTabPasta  , "FL_PASTA"    , {|| getVariavel(lxVal,@lxRet,@lcFlPasta)    }})
   aadd(laTables,{  3 , lcTabPasta  , "TP_PASTA"    , {|| getVariavel(lxVal,@lxRet,@lcTpPasta)    }})
   aadd(laTables,{  4 , lcTabSeguro , "NR_SINISTRO" , {|| getVariavel(lxVal,@lxRet,@lcNrSinistro) }})
   *                1       2            3                   4
   *                
   for ii:= 1 to len(laTables) 
   
      lcColumn:= laTables[ii,2] + "." + laTables[ii,3]
      
      aadd(laCols,lcColumn)
      
   next ii
      
   aadd(laJoin,{2 , lcTabSeguro, lcTabPasta + ".NR_PASTA = " + lcTabSeguro + ".NR_PASTA" })  
   
   aadd(laWhere,"COALESCE(" + lcTabSeguro + ".NR_SINISTRO,'') <> ''")
   
   aadd(laOrder,lcTabPasta + ".NR_PASTA") 
     
   lcMess:= "Processando a geraçao do arquivo: MarcaSin"
   dispMessage(pnHOcor,lcMess)

   * setando as variaveis de ambiente                                                                                                             
   wicSetCurVars(pnCurSet)   

   lnError:= db_select(laCols,lcTabPasta,laJoin,laWhere,laOrder)
   if lnError == -1
      lcMess:= space(3) + "??? Problemas na pesquisa na tabela: " + lcTabPasta
      llFlg := .F.
   else
      laResult:= db_fetchall()
      lnRecoun:= len(laResult) -1
   endif
   
   if llFlg
   
      for ii:= 2 to len(laResult)
      
         dispProcess(@lnCurRow,@lnRefRow,lnMaxRow,lnRecoun,pnHOcor,.f.,.f.)      

         for nn:= 1 to len(laTables)
         
            if len(laTables[nn]) > 3
               lxVal:= laResult[ii,nn]
               if valtype(laTables[nn,4]) == "B"
                  lbProc:= laTables[nn,4]
                  eval(lbProc)
                  lxVal:= lxRet
               endif
            endif
            
            if ! plFlg
               exit
            endif
            
         next nn
         
         if ! plFlg
            llFlg:= plFlg
            exit
         endif
 ? "nr_pasta",lnNrPasta
 ? "fl_pasta",lcFlPasta
 ? "tp_pasta",lcTpPasta
 ? "nr_sinistro",lcNrSinistro
 inkey(0)
         
      next ii

      if llFlg
         dispProcess(@lnCurRow,@lnRefRow,lnMaxRow,lnRecoun,pnHOcor,.f.,.f.)      
      endif
   endif
   
   if ! llFlg
      dispMessage(pnHOcor,lcMess)
   endif
   plFlg := llFlg
   
return (llFlg)
/*
* Function..: getVariavel()
* Objective.: obter o valor da variavel
* Parameters:
*   fxVal...: origem
*   fxRet...: destino
*   fxVar...: variavel
* Return....: nil  
*/
function getVariavel(fxVal,fxRet,fxVar)

   if ! empty(fxVal)
      if valtype(fxVal) == "C"
         fxVal:= alltrim(fxVal)
      endif
   endif
   
   fxRet:= fxVal
   fxVar:= fxRet
   
return (nil)

# include "/home/inso/library/prg/auxiliar.prg"
# include "/home/inso/library/prg/commons.prg"
# include "/home/inso/library/prg/errorsys.prg"
# include "/home/inso/library/prg/wiclibs.prg"
# include "/home/inso/library/prg/xhbutils.prg"
# include "/home/inso/library/prg/xhb_table_info.prg"

