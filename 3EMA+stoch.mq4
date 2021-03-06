// Advisor parameters
extern int stoploss = 75;
extern int takeprofit = 225;
extern double lot = 0.1;  		// lot size
extern int magic_num = 68405;  // identifying (magic) number of order

// Parameters of fast exponential moving average
extern int MA1_period = 3;
extern int MA1_shift = 0;

// Parameters of middle exponential moving average
extern int MA2_period = 18;
extern int MA2_shift = 0;

// Parameters of slow exponential moving average
extern int MA3_period = 75;
extern int MA3_shift = 0;

// If = true, then the deal is closed when the dotted line of Stochastic (% D) crossed the price level. 
// To close a buy trade, the dotted line must cross the 60 level top down. Sell ​​- level 40 upwards.
extern bool close_at_stoch = true;

// Parameters of stochastic oscillator
extern int stoch_param1 = 12;  // Period of the %K line
extern int stoch_param2 = 9;  // Period of the %D line
extern int stoch_param3 = 5;  // Slowing value

// Risk management
extern double max_risk = 0.03;


//--------------------------------------------------------------------

// Check if new bar(candle) is opened
bool isNewBar()
{
   static datetime BarTime;  
   bool res=false;
    
   if (BarTime != Time[0]) 
   {
      BarTime = Time[0];  
      res = true;
   } 
   return(res);
}

//--------------------------------------------------------------------

// Return number of orders by certain type
int OrdersTotalByType(int type, int mn, string sym)
{
   int num_orders = 0;
   for(int i=OrdersTotal()-1; i >= 0; i--)
   {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if(OrderMagicNumber() == mn && type == OrderType() && sym==OrderSymbol())
         num_orders++;
   }
   return(num_orders);
}

//--------------------------------------------------------------------

// Optimize lot size
double LotsOptimized()
{
   double lot_size = lot;
   lot_size = NormalizeDouble(AccountFreeMargin()*max_risk/stoploss/lot*0.01, 1);
   Alert(lot_size);
   if(lot_size < 0.1) 
		lot_size=0.1;
   return(lot_size);
}

//--------------------------------------------------------------------
bool open_order;
int buy_cond = 0;
int sell_cond = 0;
int order_id;

int start()
{
   if(!isNewBar())return(0);
   int total = OrdersTotal();  // Total amount of market and pending orders
   open_order = false;
   for(int pos=0; pos < total; pos++)
   {
      if(OrderSelect(pos, SELECT_BY_POS)==true)
      { 
         if (( OrderSymbol() == Symbol())&& (OrderMagicNumber() == magic_num )) 
         {
            open_order = true;
            order_id = OrderTicket();  // Ticket number of the currently selected order.
         }
      }
   }
   
   // Create moving averages
   double MA1_next2 = iMA(NULL, 0, MA1_period, MA1_shift, MODE_EMA, PRICE_CLOSE, 8);
   double MA3_next2 = iMA(NULL, 0, MA3_period, MA3_shift, MODE_EMA, PRICE_CLOSE, 8);
   
   double MA2_next = iMA(NULL, 0, MA2_period, MA2_shift, MODE_EMA, PRICE_CLOSE, 4);
   double MA3_next = iMA(NULL, 0, MA3_period, MA3_shift, MODE_EMA, PRICE_CLOSE, 4);
   
   double MA1_current = iMA(NULL, 0, MA1_period, MA1_shift, MODE_EMA, PRICE_CLOSE, 0);
   double MA2_current = iMA(NULL, 0, MA2_period, MA2_shift, MODE_EMA, PRICE_CLOSE, 0);
   double MA3_current = iMA(NULL, 0, MA3_period, MA3_shift, MODE_EMA, PRICE_CLOSE, 0); 
      
   if (buy_cond == 0)
   {
      if ((MA1_next2 < MA3_next2)&&(MA1_current > MA3_current))   
      {
         Print("МА1 crossed МА3 top down.");
         buy_cond = 1;
         sell_cond = 0;
      }
   }
   if (sell_cond == 0)
   {
      if ((MA1_next2 > MA3_next2)&&(MA1_current < MA3_current))   
      {
         Print("МА1 crossed МА3 upwards.");
         sell_cond = 1;
         buy_cond = 0;
      }
   }
   if ((buy_cond == 1) && (open_order == false))
   {
      if ((MA2_next < MA3_next)&&(MA2_current > MA3_current))
      {
         Print("МА2 crossed МА3 top down, open buy order.");
         buy_cond = 2;
         sell_cond = 0;
         if(OrderSend(Symbol(), OP_BUY,LotsOptimized(), Ask, 30, Ask-stoploss*k*Point, Ask+takeprofit*k*Point, "", magic_num, 0, Blue) < 0)  
            Alert("Opening position error № ", GetLastError());
      }
   }
   if ((sell_cond == 1) && (open_order == false))
   {
      if ((MA2_next > MA3_next)&&(MA2_current < MA3_current)) 
      {
         Print("МА2 crossed МА3 upwards, open sell order.");
         sell_cond = 2;
         buy_cond = 0;
         if(OrderSend(Symbol(), OP_SELL, LotsOptimized(), Bid, 30, Bid+stoploss*k*Point, Bid-takeprofit*k*Point, "", magic_num, 0, Red) < 0)
            Alert("Opening position error № ", GetLastError());
      }
   }
   
   // Create stochastic oscillator
   double stoch = iStochastic(NULL, 0, stoch_param1, stoch_param2, stoch_param3, MODE_SMA, 0, MODE_SIGNAL, 1);
   
   if ((open_order == true)&&(buy_cond == 2)&&(close_at_stoch == true))
   {
      if((stoch >= 60)&&(stoch < 60))
      {
         OrderClose(order_id, OrderLots(), Bid, 30, Green);
         buy_cond = 0;
         sell_cond = 0;
      }
   }
   if ((open_order == true)&&(sell_cond == 2)&&(close_at_stoch == true)) 
   {
      if((stoch <= 40)&&(stoch > 40))
      {
         OrderClose(order_id, OrderLots(), Ask, 30, Green);
         buy_cond = 0;
         sell_cond = 0;
      }
   }   
   if ((open_order == false)&&(close_at_stoch == false)&&((sell_cond == 2)||(buy_cond == 2)))
   {
      buy_cond = 0;
      sell_cond = 0;
   }
   if(OrdersTotalByType(OP_BUY, magic_num, Symbol()) > 0)
      if(OrdersTotalByType(OP_SELL, magic_num, Symbol()) > 0)
         return(0);
}
//+------------------------------------------------------------------+
