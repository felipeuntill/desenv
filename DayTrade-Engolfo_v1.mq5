//+------------------------------------------------------------------+
//|                                Bullish and Bearish Engulfing.mq5 |
//|                              Copyright © 2017, Vladimir Karputov |
//|                                           http://wmua.ru/slesar/ |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2017, Vladimir Karputov"
#property link      "http://wmua.ru/slesar/"
#property version   "1.005"
#property description "Bullish and Bearish Engulfing"
//---
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>  
#include <Expert\Money\MoneyFixedMargin.mqh>
CPositionInfo  m_position;                   // trade position object
CTrade         m_trade;                      // trading object
CSymbolInfo    m_symbol;                     // symbol info object
CAccountInfo   m_account;                    // account info wrapper
CMoneyFixedMargin  m_money;
//--- input parameters

input uchar                InpShift             = 1;                    // Shift in bars (from 1 to 255)
input bool                 InpOppositeSignal    = true;                 // true -> close opposite positions
input ulong                m_magic              = 270656512;            // magic number
input int                  InpRiscoMaxPontos       = 450;
input int                  InpRiscoMinPontos       = 200;
input int                  InpPontosPrimeiraOperacao = 400;

input string inicio="10:00"; //Horario de inicio(entradas);
input string termino="16:40"; //Horario de termino(entradas);
input string fechamento="17:45"; //Horario de fechamento(entradas);
input string data_hora_inicio = "02/05/2019 09:00:00";
input string data_hora_fechamento = "03/05/2019 18:00:00";
MqlDateTime horario_inicio,horario_termino,horario_fechamento,horario_atual;
//---
ulong                      m_slippage=30;                               // slippage
double                     ExtDistance=0.0;
double                     m_lots_min=0.0;
double                     m_adjusted_point;                            // point value adjusted for 3 or 5 points
bool                       trade_ativo = false;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpShift<1)
     {
      Print("The parameter \"Shift\" can not be less than \"1\"");
      return(INIT_PARAMETERS_INCORRECT);
     }
  trade_ativo = true;
 //---
  Print("Data Fechamento ->", StringToTime(data_hora_fechamento));
 //--- object for working with the account
   CAccountInfo account;
//--- receiving the account number, the Expert Advisor is launched at
   long login=account.Login();
   Print("Login=",login);
//--- clarifying account type
   ENUM_ACCOUNT_TRADE_MODE account_type=account.TradeMode();
//--- if the account is real, the Expert Advisor is stopped immediately!
   if(account_type==ACCOUNT_TRADE_MODE_REAL)
     {
      MessageBox("Trading on a real account is forbidden, disabling","The Expert Advisor has been launched on a real account!");
      return(-1);
     }
//--- displaying the account type    
   Print("Account type: ",EnumToString(account_type));
//--- clarifying if we can trade on this account
   if(account.TradeAllowed())
      Print("Trading on this account is allowed");
   else
      Print("Trading on this account is forbidden: you may have entered using the Investor password");
//--- clarifying if we can use an Expert Advisor on this account
   if(account.TradeExpert())
      Print("Automated trading on this account is allowed");
   else
      Print("Automated trading using Expert Advisors and scripts on this account is forbidden");
//--- clarifying if the permissible number of orders has been set
   int orders_limit=account.LimitOrders();
   if(orders_limit!=0)Print("Maximum permissible amount of active pending orders: ",orders_limit);
//--- displaying company and server names
   Print(account.Company(),": server ",account.Server());
//--- displaying balance and current profit on the account in the end
   Print("Balance=",account.Balance(),"  Profit=",account.Profit(),"   Equity=",account.Equity());
   Print(__FUNCTION__,"  completed"); //---
     
   DetailsSymbol();  
   
   
     
     
     
//---
   m_symbol.Name(Symbol());                  // sets symbol name
   Print("Simbolo nome =",m_symbol.Name());
   RefreshRates();
   m_symbol.Refresh();

   m_lots_min=m_symbol.LotsMin();
   Print("Lote minimo=",m_lots_min);

//string err_text="";
//if(!CheckVolumeValue(m_lots,err_text))
//  {
//   Print(err_text);
//   return(INIT_PARAMETERS_INCORRECT);
//  }
//---
   m_trade.SetExpertMagicNumber(m_magic);
//---
   if(IsFillingTypeAllowed(Symbol(),SYMBOL_FILLING_FOK))
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   else if(IsFillingTypeAllowed(Symbol(),SYMBOL_FILLING_IOC))
      m_trade.SetTypeFilling(ORDER_FILLING_IOC);
   else
      m_trade.SetTypeFilling(ORDER_FILLING_RETURN);
//---
   m_trade.SetDeviationInPoints(m_slippage);
//--- tuning for 3 or 5 digits
   int digits_adjust=1;
   Print("Digitos",m_symbol.Digits());
   if(m_symbol.Digits()==3 || m_symbol.Digits()==5)
      digits_adjust=10;
   m_adjusted_point=m_symbol.Point()*digits_adjust;
   


//---
   if(!m_money.Init(GetPointer(m_symbol),Period(),m_symbol.Point()*digits_adjust))
      return(INIT_FAILED);
  
   
   
   TimeToStruct(StringToTime(inicio),horario_inicio);         //+-------------------------------------+
   TimeToStruct(StringToTime(termino),horario_termino);       //| Conversão das variaveis para mql    |
   //TimeToStruct(StringToTime(fechamento),horario_fechamento); //+-------------------------------------+
   
//verificação de erros nas entradas de horario
//   if(horario_inicio.hour>horario_termino.hour || (horario_inicio.hour==horario_termino.hour && horario_inicio.min>horario_termino.min))
//     {
//      printf ( "Parametos de horarios invalidos!" );
//      return INIT_FAILED;
//     }
//     
//    if(horario_termino.hour>horario_fechamento.hour || (horario_termino.hour==horario_fechamento.hour && horario_termino.min>horario_fechamento.min))
//     {
//      printf("Parametos de horarios invalidos!");
//      return INIT_FAILED;
//      }
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   
   //if (HorarioRobo()) {
   static datetime PrevBars=0;
   datetime time_0=iTime(m_symbol.Name(),Period(),0);
   if(time_0==PrevBars)
      return;
   PrevBars=time_0;

   MqlRates rates[];
   ArraySetAsSeries(rates,true); // true -> rates[0] - the rightmost bar
   int start_pos=InpShift;
   int copied=CopyRates(m_symbol.Name(),Period(),start_pos,2,rates);
   if(copied==2)
     {
      for(int i = OrdersTotal() - 1; i >= 0; i--) {
         if(OrderGetTicket(i) > 0) {
            m_trade.OrderDelete(OrderGetTicket(i));
            Print("Ordem pendente deletada");
         }
      }
      
    for(int i=PositionsTotal()-1;i>=0;i--) {// returns the number of current orders
      if(m_position.SelectByIndex(i)) {    // selects the position by index for further access to its properties
         if(m_position.Symbol()==m_symbol.Name())
           return;
      }   
    }  
     
      // OHLC
      Print("Horario inicial=", rates[0].time);
      Print("Abertura=", rates[0].open);
      Print("Fechamento=", rates[0].close);
      
      double max_serie = 0.0;
      double min_serie = 0.0;
      double diff_serie = 0.0;
      if (rates[0].high > rates[1].high) 
      {
        max_serie = rates[0].high;
      } else {
        max_serie = rates[1].high;
      }
      
      if (rates[0].low < rates[1].low) 
      {
        min_serie = rates[0].low;
      } else {
        min_serie = rates[1].low;
      }
      
      diff_serie = max_serie - min_serie;
      
      if(rates[0].open<rates[0].close && rates[1].open>rates[1].close)  // Candle recente de alta e Candle anterior de baixa
        {
          double cl_recente = rates[0].close - rates[0].open;
          double cl_anterior = rates[1].open - rates[1].close;
          Print("Recente= ",cl_recente,"Anterior= ",cl_anterior,"Resultado= ", cl_recente > cl_anterior);
          bool enf_alta = cl_recente > cl_anterior;
          Print("Engolfo de alta ", enf_alta);
          
          if(enf_alta )
            {
              Print("Max,Min= ",max_serie - min_serie);
             
              if (diff_serie <= InpRiscoMaxPontos && diff_serie >= InpRiscoMinPontos)  
                {
                  Print("Operacao de compra");
                  Print("Stop loss=",min_serie,"Stop Gain=",max_serie + diff_serie);
                  //OpenBuy(min_serie, max_serie + diff_serie);
                  
                   if (trade_ativo) {
                     OpenBuyStop(1,m_symbol.Name(),max_serie,min_serie,max_serie + diff_serie);
                   }
                }
            }
         }
         
       if(rates[0].open>rates[0].close && rates[1].open<rates[1].close)  // Candle recente de baixa e Candle anterior de alta
         {
          double cl_recente = rates[0].open - rates[0].close;
          double cl_anterior = rates[1].close - rates[1].open;
          Print("Recente= ",cl_recente,"Anterior= ",cl_anterior,"Resultado= ", cl_recente > cl_anterior);
          bool enf_baixa = cl_recente > cl_anterior;
          Print("Engolfo de baixa ", enf_baixa);
          
          if(enf_baixa )
            {
              Print("Max,Min= ",max_serie - min_serie);
              if (diff_serie <= InpRiscoMaxPontos && diff_serie >= InpRiscoMinPontos)  
                {
                  Print("Operacao de Venda");
                  Print("Stop loss=",max_serie,"Stop Gain=",min_serie - diff_serie);
                  
                  if (trade_ativo) {
                    OpenSellStop(1,m_symbol.Name(),min_serie,max_serie,min_serie - diff_serie);
                  }
                }
            }
          
         }
     }
   else
     {
      PrevBars=iTime(m_symbol.Name(),Period(),1);
      Print("Failed to get history data for the symbol ",Symbol());
     }
//---
   return;
  }
 //}
  
bool DayTradePeriodAllowed()
 {

   MqlDateTime dt_struct;
   datetime dtSer=TimeCurrent(dt_struct);
   
   printf("Server time: %d:%d:%d ; Just hours: %d ; Just minutes: %d",dt_struct.hour,dt_struct.min,dt_struct.sec,dt_struct.hour,dt_struct.min);
   return(true);
      
}
//+------------------------------------------------------------------+
//| Refreshes the symbol quotes data                                 |
//+------------------------------------------------------------------+
bool RefreshRates()
  {
//--- refresh rates
   if(!m_symbol.RefreshRates())
      return(false);
//--- protection against the return value of "zero"
   if(m_symbol.Ask()==0 || m_symbol.Bid()==0)
      return(false);
//---
   return(true);
  }
//+------------------------------------------------------------------+ 
//| Checks if the specified filling mode is allowed                  | 
//+------------------------------------------------------------------+ 
bool IsFillingTypeAllowed(string symbol,int fill_type)
  {
//--- Obtain the value of the property that describes allowed filling modes 
   int filling=(int)SymbolInfoInteger(symbol,SYMBOL_FILLING_MODE);
   Print("Simbolo filling = ", filling);
//--- Return true, if mode fill_type is allowed 
   return((filling & fill_type)==fill_type);
  }
//+------------------------------------------------------------------+
//| Close Positions                                                  |
//+------------------------------------------------------------------+
void ClosePositions(ENUM_POSITION_TYPE pos_type)
  {
   for(int i=PositionsTotal()-1;i>=0;i--) // returns the number of current orders
      if(m_position.SelectByIndex(i))     // selects the position by index for further access to its properties
         if(m_position.Symbol()==m_symbol.Name() && m_position.Magic()==m_magic)
            if(m_position.PositionType()==pos_type) // gets the position type
               m_trade.PositionClose(m_position.Ticket()); // close a position by the specified symbol
  }
  
void History() {
 
  
   ulong    ticket=0; 
   double   price; 
   double   profit=0; 
   datetime time; 
   string   symbol; 
   long     type; 
   long      entry;

   HistorySelect(StringToTime(data_hora_inicio),StringToTime(data_hora_fechamento)); 
   uint     total=HistoryDealsTotal(); 
  
     for(uint i=0;i<total;i++) 
     { 
      //--- tentar obter ticket negócios 
      if((ticket=HistoryDealGetTicket(i))>0) 
        { 
         //--- obter as propriedades negócios 
         price =HistoryDealGetDouble(ticket,DEAL_PRICE); 
         time  =(datetime)HistoryDealGetInteger(ticket,DEAL_TIME); 
         symbol=HistoryDealGetString(ticket,DEAL_SYMBOL); 
         type  =HistoryDealGetInteger(ticket,DEAL_TYPE); 
         entry  =HistoryDealGetInteger(ticket,DEAL_ENTRY); 
         profit= HistoryDealGetDouble(ticket,DEAL_PROFIT); 
         
         Print("History Strategy ->",price,"|",ticket, "|",type,"|",profit,"|",entry);
      
        } 
     } 
}

void HistoryStrategy() {
 
  
   //ulong    ticket=0; 
   //double   price; 
   //double   profit=0; 
   //datetime time; 
   //string   symbol; 
   //long     type; 
   //long     entry;
   double     pontos_ganhos = 0;
   double     pontos_perdidos = 0;
   bool     consecutivos[];
   uint       contador = 0;
  
   HistorySelect(StringToTime(data_hora_inicio),StringToTime(data_hora_fechamento)); 
   uint total=HistoryDealsTotal(); 
   
    
  
     for(uint i=0;i<total;i++) 
     { 
      //Calculo pontos somente na sáída da posição 
      if (MathMod(total,2) == 0) {
          ArrayResize(consecutivos,total/2);
      
          ulong ticketAtual = HistoryDealGetTicket(i);
          ulong ticketAnterior = HistoryDealGetTicket(i-1);
        
          if(ticketAtual >0 && ticketAnterior > 0) {
             long entryAtual = HistoryDealGetInteger(ticketAtual,DEAL_ENTRY);  
             
             if (entryAtual==DEAL_ENTRY_OUT) {
                 double priceAtual    = HistoryDealGetDouble(ticketAtual,DEAL_PRICE);
                 double profitAtual  = HistoryDealGetDouble(ticketAtual,DEAL_PROFIT); 
                 
                 double priceAnterior = HistoryDealGetDouble(ticketAnterior,DEAL_PRICE);
                
                 double resultado = priceAtual - priceAnterior;
                   
                 if (profitAtual > 0) {
                    
                    ArrayFill(consecutivos,contador,1,true);
                    contador++;
                    
                    pontos_ganhos += MathAbs(resultado); 
                    Print("Pontos ganhos-->",pontos_ganhos);
                    //Primeiro negociação do dia com lucro superior a X pontos
                    if (MathAbs(resultado) > InpPontosPrimeiraOperacao && total==2) {
                        Print("Para de operar primeiro operação limite antigido");
                        trade_ativo = false;
                    }
                    //Limite de pontos ganhos no dia
                    if (pontos_ganhos > 450) {
                        Print("Para de operar limite de pontos antigido");
                        trade_ativo = false;
                    }
                    
                    
                    
                 } else if(profitAtual < 0) {
                    
                    ArrayFill(consecutivos,contador,1,false);
                    contador++;
                   
                    pontos_perdidos += MathAbs(resultado); 
                    Print("Pontos perdidos-->",pontos_perdidos);
                    //Limite de pontos perdidos no dia
                    if ( pontos_perdidos >450) {
                       Print("Para de operar limite de pontos negativo antigido");
                       trade_ativo = false;
                    }
                 }
            }
                
         }
       }  
     }
     
     // Quantidades consecutivas de ganhos ou perdas 
     for(uint j=0;j<ArraySize(consecutivos);j++) { 
          Print("array de objetos--> Posicao|",j,"-",consecutivos[j]);  
          // Duas posições consecutivas com ganhos
          if ((j != 0) && (consecutivos[j]==true && consecutivos[j-1]==true)) {
            Print("Duas operações com lucro na sequencia, parar de operar");
            trade_ativo = false;
          }
           if ((j > 1) && (consecutivos[j]==false && consecutivos[j-1]==false && consecutivos[j-2]==false  )) {
            Print("Tres operações com loss na sequencia, parar de operar");
            trade_ativo = false;
          }
        
     } 
 } 

  
  
//+------------------------------------------------------------------+
//| Open Buy position                                                |
//+------------------------------------------------------------------+
bool CheckVolumeOrder(double requestVolume,ENUM_ORDER_TYPE orderType ) 
{
 // bool check = m_trade.CheckVolume(m_symbol.Name(),requestVolume,m_symbol.Ask(),orderType);
  return true;//check;
}

void OpenBuyStop(double requestVolume,string symbol, double price, double sl,double sg) 
{
   sl=m_symbol.NormalizePrice(sl);
   sg=m_symbol.NormalizePrice(sg);
   datetime expiration= TimeTradeServer()+PeriodSeconds(PERIOD_M10);
   Print("Time Expiration=", expiration);
   
   if (CheckVolumeOrder(requestVolume,ORDER_TYPE_BUY_STOP))
   {
      if(!m_trade.BuyStop(requestVolume,price,symbol,sl,sg,ORDER_TIME_GTC,expiration))
     {
      //--- failure message
      Print("BuyStop() method failed. Return code=",m_trade.ResultRetcode(),
            ". Code description: ",m_trade.ResultRetcodeDescription());
     }
   else
     {
      Print("BuyStop() method executed successfully. Return code=",m_trade.ResultRetcode(),
            " (",m_trade.ResultRetcodeDescription(),")");
     }
   } 
   else
   {
    Print("Volume solicitado não disponivel = ", requestVolume);
    return;
   }
    
   

}

void OpenSellStop(double requestVolume,string symbol, double price, double sl,double sg)
{
   sl=m_symbol.NormalizePrice(sl);
   sg=m_symbol.NormalizePrice(sg);
   datetime expiration= TimeTradeServer()+PeriodSeconds(PERIOD_M10);
   Print("Time Expiration=", expiration);
   
   if (CheckVolumeOrder(requestVolume,ORDER_TYPE_SELL_STOP))
   {
      if(!m_trade.SellStop(requestVolume,price,symbol,sl,sg,ORDER_TIME_GTC,expiration))
     {
      //--- failure message
      Print("SellStop() method failed. Return code=",m_trade.ResultRetcode(),
            ". Code description: ",m_trade.ResultRetcodeDescription());
     }
   else
     {
      Print("SellStop() method executed successfully. Return code=",m_trade.ResultRetcode(),
            " (",m_trade.ResultRetcodeDescription(),")");
     }
   } 
   else
   {
    Print("Volume solicitado não disponivel = ", requestVolume);
    return;
   }
    
   

}

void OpenSellLimit(double requestVolume,string symbol,double price) 
{
   double sl=m_symbol.NormalizePrice(0.0);
   double sg=m_symbol.NormalizePrice(0.0);
   datetime expiration= TimeTradeServer()+PeriodSeconds(PERIOD_M10);
   Print("Time Expiration=", expiration);
   
   if (CheckVolumeOrder(requestVolume,ORDER_TYPE_SELL_LIMIT))
   {
      if(!m_trade.SellLimit(requestVolume,price,symbol,sl,sg,ORDER_TIME_GTC,expiration))
     {
      //--- failure message
      Print("SellLimit() method failed. Return code=",m_trade.ResultRetcode(),
            ". Code description: ",m_trade.ResultRetcodeDescription());
     }
   else
     {
      Print("SellLimit() method executed successfully. Return code=",m_trade.ResultRetcode(),
            " (",m_trade.ResultRetcodeDescription(),")");
     }
   } 
   else
   {
    Print("Volume solicitado não disponivel = ", requestVolume);
    return;
   }
    
   

}



void OpenBuy(double sl,double tp)
  {
   sl=m_symbol.NormalizePrice(sl);
   tp=m_symbol.NormalizePrice(tp);
   
 
 
   double check_open_long_lot=m_money.CheckOpenLong(m_symbol.Ask(),sl);
//Print("sl=",DoubleToString(sl,m_symbol.Digits()),
//      ", CheckOpenLong: ",DoubleToString(check_open_long_lot,2),
//      ", Balance: ",    DoubleToString(m_account.Balance(),2),
//      ", Equity: ",     DoubleToString(m_account.Equity(),2),
//      ", FreeMargin: ", DoubleToString(m_account.FreeMargin(),2));
   if(check_open_long_lot==0.0)
      return;

//--- check volume before OrderSend to avoid "not enough money" error (CTrade)
   double check_volume_lot= m_trade.CheckVolume(m_symbol.Name(),check_open_long_lot,m_symbol.Ask(),ORDER_TYPE_BUY);

   if(check_volume_lot!=0.0)
      if(check_volume_lot>=check_open_long_lot)
        {
         if(m_trade.Buy(1,NULL,m_symbol.Ask(),sl,tp))
           {
            if(m_trade.ResultDeal()==0)
              {
               Print("Buy -> false. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
              }
            else
              {
               Print("Buy -> true. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
              }
           }
         else
           {
            Print("Buy -> false. Result Retcode: ",m_trade.ResultRetcode(),
                  ", description of result: ",m_trade.ResultRetcodeDescription());
           }
        }
//---
  }
//+------------------------------------------------------------------+
//| Open Sell position                                               |
//+------------------------------------------------------------------+

void DetailsSymbol()
  {
  
  //--- object for receiving symbol settings
   CSymbolInfo symbol_info;
//--- set the name for the appropriate symbol
   symbol_info.Name(_Symbol);
//--- receive current rates and display
   symbol_info.RefreshRates();
   Print(symbol_info.Name()," (",symbol_info.Description(),")",
         "  Bid=",symbol_info.Bid(),"   Ask=",symbol_info.Ask());
//--- receive minimum freeze levels for trade operations
   Print("StopsLevel=",symbol_info.StopsLevel()," pips, FreezeLevel=",
         symbol_info.FreezeLevel()," pips");
//--- receive the number of decimal places and point size
   Print("Digits=",symbol_info.Digits(),
         ", Point=",DoubleToString(symbol_info.Point(),symbol_info.Digits()));
//--- spread info
   Print("SpreadFloat=",symbol_info.SpreadFloat(),", Spread(current)=",
         symbol_info.Spread()," pips");
//--- request order execution type for limitations
   Print("Limitations for trade operations: ",EnumToString(symbol_info.TradeMode()),
         " (",symbol_info.TradeModeDescription(),")");
//--- clarifying trades execution mode
   Print("Trades execution mode: ",EnumToString(symbol_info.TradeExecution()),
         " (",symbol_info.TradeExecutionDescription(),")");
//--- clarifying contracts price calculation method
   Print("Contract price calculation: ",EnumToString(symbol_info.TradeCalcMode()),
         " (",symbol_info.TradeCalcModeDescription(),")");
//--- sizes of contracts
   Print("Standard contract size: ",symbol_info.ContractSize(),
         " (",symbol_info.CurrencyBase(),")");
//--- minimum and maximum volumes in trade operations
   Print("Volume info: LotsMin=",symbol_info.LotsMin(),"  LotsMax=",symbol_info.LotsMax(),
         "  LotsStep=",symbol_info.LotsStep());
//--- 
   Print(__FUNCTION__,"  completed");
//---
   return;
  
  
  }  
  
void OnTradeTransaction(const MqlTradeTransaction &trans, 
                        const MqlTradeRequest &request, 
                        const MqlTradeResult &result) 
  { 
//--- 
 
  
   static int counter=0;   // contador de chamadas da OnTradeTransaction() 
   static uint lasttime=0; // hora da última chamada da OnTradeTransaction() 
//--- 
   uint time=GetTickCount(); 
//--- se a última operação tiver sido realizada há mais de 1 segundo, 
   if(time-lasttime>1000) 
     { 
      counter=0; // significa que se trata de uma nova operação de negociação e, portanto, podemos redefinir o contador 
      if(IS_DEBUG_MODE) 
         Print(" Nova operação de negociação"); 
     } 
   lasttime=time; 
   counter++; 
   Print(counter,". ",__FUNCTION__); 
//--- resultado da execução do pedido de negociação 
   ulong            lastOrderID   =trans.order; 
   ENUM_ORDER_TYPE  lastOrderType =trans.order_type; 
   ENUM_ORDER_STATE lastOrderState=trans.order_state; 
//--- nome do símbolo segundo o qual foi realizada a transação 
   string trans_symbol=trans.symbol; 
//--- tipo de transação 
   ENUM_TRADE_TRANSACTION_TYPE  trans_type=trans.type; 
   

   if(HistoryDealSelect(trans.deal) == true)
{
     ENUM_DEAL_ENTRY deal_entry=(ENUM_DEAL_ENTRY) HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
     ENUM_DEAL_REASON deal_reason=(ENUM_DEAL_REASON) HistoryDealGetInteger(trans.deal,DEAL_REASON);
     PrintFormat("deal entry type=%s trans type=%s trans deal type=%s order-ticket=%d deal-ticket=%d deal-reason=%s",EnumToString(deal_entry),EnumToString(trans.type),EnumToString(trans.deal_type),trans.order,trans.deal,EnumToString(deal_reason));
}
  
   
   switch(trans.type) 
     { 
      case  TRADE_TRANSACTION_POSITION:   // alteração da posição 
        { 
         ulong pos_ID=trans.position; 
         PrintFormat("MqlTradeTransaction: Position  #%d %s modified: SL=%.5f TP=%.5f", 
                     pos_ID,trans_symbol,trans.price_sl,trans.price_tp); 
        } 
      break; 
      case TRADE_TRANSACTION_REQUEST:     // envio do pedido de negociação 
         PrintFormat("MqlTradeTransaction: TRADE_TRANSACTION_REQUEST"); 
         break; 
      case TRADE_TRANSACTION_DEAL_ADD:    // adição da transação 
        { 
         ulong           lastDealID   =trans.deal; 
         ENUM_DEAL_TYPE  lastDealType =trans.deal_type; 
       
       
        ENUM_DEAL_ENTRY deal_entry=(ENUM_DEAL_ENTRY) HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
         double        lastDealVolume=trans.volume; 
         //--- identificador da transação no sistema externo - bilhete atribuído pela bolsa 
         string Exchange_ticket=""; 
         if(HistoryDealSelect(lastDealID)) 
            Exchange_ticket=HistoryDealGetString(lastDealID,DEAL_EXTERNAL_ID); 
         if(Exchange_ticket!="") 
            Exchange_ticket=StringFormat("(Exchange deal=%s)",Exchange_ticket); 
  
         PrintFormat("MqlTradeTransaction: %s deal #%d %s %s %.2f lot   %s",EnumToString(trans_type), 
                     lastDealID,EnumToString(lastDealType),trans_symbol,lastDealVolume,Exchange_ticket); 
                     
         if ( deal_entry==DEAL_ENTRY_OUT) {
            HistoryStrategy();
         }
                     
//            for(int i=PositionsTotal()-1;i>=0;i--) {// returns the number of current orders
//               if(m_position.SelectByIndex(i)) {    // selects the position by index for further access to its properties
//                  if(m_position.Symbol()==m_symbol.Name() && m_position.Type()==POSITION_TYPE_BUY && lastOrderType==ORDER_TYPE_BUY_STOP) {
//                    
//                     Print("Posicao=", m_position.TakeProfit());
//                     Print("Posicao=", m_position.StopLoss());
//                     OpenSellLimit(1,m_symbol.Name(),m_position.TakeProfit());
//                     OpenSellStop(1,m_symbol.Name(),m_position.StopLoss());
//                   } 
//                   else if(m_position.Symbol()==m_symbol.Name() && m_position.Type()==POSITION_TYPE_BUY && lastOrderType!=ORDER_TYPE_BUY_STOP) {
//                       for(int i = OrdersTotal() - 1; i >= 0; i--) {
//                           if(OrderGetTicket(i) > 0) {
//                              m_trade.OrderDelete(OrderGetTicket(i));
//                              Print("Ordem pendente deletada no transtion");
//                           }
//                        }
//                   } 
//                      
//                     
//                     //for(int i = OrdersTotal() - 1; i >= 0; i--) {
//                     //   if(OrderGetTicket(i) > 0 && OrderGetInteger(ORDER_POSITION_ID)==) {
//                     //      m_trade.
//                     //      Print("Ordem pendente deletada");
//                     //   }
//                     //}
//                 
//                     
//               }   
//              
//            }             
                     
                     
        } 
      break; 
      case TRADE_TRANSACTION_HISTORY_ADD: // adição da ordem ao histórico 
        { 
         //--- identificador da transação no sistema externo - bilhete atribuído pela bolsa 
         string Exchange_ticket=""; 
         if(lastOrderState==ORDER_STATE_FILLED) 
           { 
            if(HistoryOrderSelect(lastOrderID)) 
               Exchange_ticket=HistoryOrderGetString(lastOrderID,ORDER_EXTERNAL_ID); 
            if(Exchange_ticket!="") 
               Exchange_ticket=StringFormat("(Exchange ticket=%s)",Exchange_ticket); 
           } 
         PrintFormat("MqlTradeTransaction: %s order #%d %s %s %s   %s",EnumToString(trans_type), 
                     lastOrderID,EnumToString(lastOrderType),trans_symbol,EnumToString(lastOrderState),Exchange_ticket); 
        } 
      break; 
      default: // outras transações   
        { 
         //--- identificador da ordem no sistema externo - bilhete atribuído pela Bolsa de Valores de Moscou 
         string Exchange_ticket=""; 
         if(lastOrderState==ORDER_STATE_PLACED) 
           { 
            if(OrderSelect(lastOrderID)) 
               Exchange_ticket=OrderGetString(ORDER_EXTERNAL_ID); 
            if(Exchange_ticket!="") 
               Exchange_ticket=StringFormat("Exchange ticket=%s",Exchange_ticket); 
           } 
         PrintFormat("MqlTradeTransaction(Default, orderPlaced): %s order #%d %s %s   %s",EnumToString(trans_type), 
                     lastOrderID,EnumToString(lastOrderType),EnumToString(lastOrderState),Exchange_ticket); 
        } 
      break; 
     } 
//--- bilhete da ordem     
   ulong orderID_result=result.order; 
   string retcode_result=GetRetcodeID(result.retcode); 
   Print("Retorno da transacao",result.retcode);
   if(orderID_result!=0) 
      PrintFormat("MqlTradeResult: order #%d retcode=%s ",orderID_result,retcode_result); 
//---    
  } 
  
 string GetRetcodeID(int retcode) 
  { 
   switch(retcode) 
     { 
      case 10004: return("TRADE_RETCODE_REQUOTE");             break; 
      case 10006: return("TRADE_RETCODE_REJECT");              break; 
      case 10007: return("TRADE_RETCODE_CANCEL");              break; 
      case 10008: return("TRADE_RETCODE_PLACED");              break; 
      case 10009: return("TRADE_RETCODE_DONE");                break; 
      case 10010: return("TRADE_RETCODE_DONE_PARTIAL");        break; 
      case 10011: return("TRADE_RETCODE_ERROR");               break; 
      case 10012: return("TRADE_RETCODE_TIMEOUT");             break; 
      case 10013: return("TRADE_RETCODE_INVALID");             break; 
      case 10014: return("TRADE_RETCODE_INVALID_VOLUME");      break; 
      case 10015: return("TRADE_RETCODE_INVALID_PRICE");       break; 
      case 10016: return("TRADE_RETCODE_INVALID_STOPS");       break; 
      case 10017: return("TRADE_RETCODE_TRADE_DISABLED");      break; 
      case 10018: return("TRADE_RETCODE_MARKET_CLOSED");       break; 
      case 10019: return("TRADE_RETCODE_NO_MONEY");            break; 
      case 10020: return("TRADE_RETCODE_PRICE_CHANGED");       break; 
      case 10021: return("TRADE_RETCODE_PRICE_OFF");           break; 
      case 10022: return("TRADE_RETCODE_INVALID_EXPIRATION");  break; 
      case 10023: return("TRADE_RETCODE_ORDER_CHANGED");       break; 
      case 10024: return("TRADE_RETCODE_TOO_MANY_REQUESTS");   break; 
      case 10025: return("TRADE_RETCODE_NO_CHANGES");          break; 
      case 10026: return("TRADE_RETCODE_SERVER_DISABLES_AT");  break; 
      case 10027: return("TRADE_RETCODE_CLIENT_DISABLES_AT");  break; 
      case 10028: return("TRADE_RETCODE_LOCKED");              break; 
      case 10029: return("TRADE_RETCODE_FROZEN");              break; 
      case 10030: return("TRADE_RETCODE_INVALID_FILL");        break; 
      case 10031: return("TRADE_RETCODE_CONNECTION");          break; 
      case 10032: return("TRADE_RETCODE_ONLY_REAL");           break; 
      case 10033: return("TRADE_RETCODE_LIMIT_ORDERS");        break; 
      case 10034: return("TRADE_RETCODE_LIMIT_VOLUME");        break; 
      case 10035: return("TRADE_RETCODE_INVALID_ORDER");       break; 
      case 10036: return("TRADE_RETCODE_POSITION_CLOSED");     break; 
      default: 
         return("TRADE_RETCODE_UNKNOWN="+IntegerToString(retcode)); 
         break; 
     } 
//--- 
  }
  
     

void OpenSell(double sl,double tp)
  {
   sl=m_symbol.NormalizePrice(sl);
   tp=m_symbol.NormalizePrice(tp);

   double check_open_short_lot=m_money.CheckOpenShort(m_symbol.Bid(),sl);
//Print("sl=",DoubleToString(sl,m_symbol.Digits()),
//      ", CheckOpenLong: ",DoubleToString(check_open_short_lot,2),
//      ", Balance: ",    DoubleToString(m_account.Balance(),2),
//      ", Equity: ",     DoubleToString(m_account.Equity(),2),
//      ", FreeMargin: ", DoubleToString(m_account.FreeMargin(),2));
   if(check_open_short_lot==0.0)
      return;

//--- check volume before OrderSend to avoid "not enough money" error (CTrade)
   double check_volume_lot=m_trade.CheckVolume(m_symbol.Name(),check_open_short_lot,m_symbol.Bid(),ORDER_TYPE_SELL);

   if(check_volume_lot!=0.0)
      if(check_volume_lot>=check_open_short_lot)
        {
         if(m_trade.Sell(check_open_short_lot,NULL,m_symbol.Bid(),sl,tp))
           {
            if(m_trade.ResultDeal()==0)
              {
               Print("Sell -> false. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
              }
            else
              {
               Print("Sell -> true. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
              }
           }
         else
           {
            Print("Sell -> false. Result Retcode: ",m_trade.ResultRetcode(),
                  ", description of result: ",m_trade.ResultRetcodeDescription());
           }
        }
//---
  }
  
  bool HorarioRobo()
      {
       TimeToStruct(TimeCurrent(),horario_atual);

      if(horario_atual.hour >= horario_inicio.hour && horario_atual.hour <= horario_termino.hour)
   {
      // Hora atual igual a de início
      if(horario_atual.hour == horario_inicio.hour)
         // Se minuto atual maior ou igual ao de início => está no horário de entradas
         if(horario_atual.min >= horario_inicio.min)
            return true;
         // Do contrário não está no horário de entradas
         else
            return false;
      
      // Hora atual igual a de término
      if(horario_atual.hour == horario_termino.hour)
         // Se minuto atual menor ou igual ao de término => está no horário de entradas
         if(horario_atual.min <= horario_termino.min)
            return true;
         // Do contrário não está no horário de entradas
         else
            return false;
      
      // Hora atual maior que a de início e menor que a de término
      return true;
   }
   
   // Hora fora do horário de entradas
   return false;
}
  
 
//+------------------------------------------------------------------+
