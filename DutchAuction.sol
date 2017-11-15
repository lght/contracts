//! Copyright Parity Technologies, 2017.
//! Released under the Apache Licence 2.

/// Compiler 0.4.11 needed for `transfer()`
pragma solidity ^0.4.11;

/// Stripped down ERC20 standard token interface.
interface Token {
	function transfer(address _to, uint256 _value) returns (bool success);
}

/// Simple Dutch Auction contract. Price starts high and monotonically decreases
/// until all tokens are sold at the current price with currently received
/// funds.
contract DutchAuction {
	/// Someone bought in at a particular max-price.
	event Buyin(address indexed who, uint price, uint spent, uint refund);

	/// The sale just ended with the current price.
	event Ended(uint price);

	/// Finalised the purchase for `who`, who has been given `tokens` tokens and
	/// refunded `refund` (which is the remainder since only a whole number of
	/// tokens may be purchased).
	event Finalised(address indexed who, uint tokens);

	/// Auction is over. All accounts finalised.
	event Retired();

	/// Simple constructor.
	function DutchAuction(address _tokenContract, address _treasury, address _admin, uint _beginTime, uint _beginPrice, uint _saleSpeed, uint _tokenCap) {
		tokenContract = Token(_tokenContract);
		treasury = _treasury;
		admin = _admin;
		beginTime = _beginTime;
		beginPrice = _beginPrice;
		saleSpeed = _saleSpeed;
		tokenCap = _tokenCap;
		endTime = beginTime + beginPrice / saleSpeed;
	}

	/// Buyin function. Throws if the sale is not active. May refund some of the
	/// funds if they would end the sale.
	function()
		payable
	public
	when_not_halted
	when_active
	avoid_dust
	{
		uint price = currentPrice();
		uint tokens = msg.value / price;
		uint refund = 0;
		uint accepted = msg.value;

		// if we've asked for too many, send back the extra.
		if (tokens > tokensAvailable()) {
			refund = (tokens - tokensAvailable()) * price;
			// add refund to sender's balance
			// withdraw using withdrawRefund(address _who)
			refundBalances[msg.sender] = refund;
			tokens = tokensAvailable();
			accepted -= refund;
		}

		// send rest to treasury
		// withdraw using treasuryWithdrawal(address _treasury)
		treasuryBalance[treasury] += accepted;
		
		// record the acceptance.
		participants[msg.sender] += accepted;
		totalReceived += accepted;
		uint targetPrice = totalReceived / tokenCap;
		uint salePriceDrop = beginPrice - targetPrice;
		uint saleDuration = salePriceDrop / saleSpeed;
		endTime = beginTime + saleDuration;
		Buyin(msg.sender, price, accepted, refund);
	}

	function withdrawRefund(address _who)
	    public
		only_participants(_who)
	{
	    require(refundBalances[_who] > 0);
	
	    uint ref = refundBalances[_who];
	    refundBalances[_who] = 0;
	    require(_who.transfer(ref));
	}
	
	function withdrawTokens(address _who)
		public
		only_participants(_who)
		when_all_finalised
	{
		assert(tokenBalances[_who] > 0);
		
		uint tk = tokenBalances[_who];
		tokenBalances[_who] = 0;
		require(_who.transfer(tk));
	}
	
	function treasuryWithdrawal(address _treasury)
		public
		only_treasury
	{
		require(treasuryBalance[_treasury] > 0);
		
		uint ref = refundBalances[_treasury];
		refundBalances[_treasury] = 0;
		require(_treasury.transfer(ref));
	} 


	/// Mint tokens for a particular participant.
	function finalise(address _who)
		public
		when_not_halted
		when_ended
		only_participants(_who)
	{
		// end the auction if we're the first one to finalise.
		if (endPrice == 0) {
			endPrice = totalReceived / tokenCap;
			Ended(endPrice);
		}

		// enact the purchase.
		uint tokens = participants[_who] / endPrice;
		uint refund = participants[_who] - endPrice * tokens;
		totalFinalised += participants[_who];
		participants[_who] = 0;
        // changed to withdraw pattern
        // use withdawTokens(address _who) 
		tokenBalances[_who] = tokens;

		Finalised(_who, tokens);

		if (totalFinalised == totalReceived) {
			Retired();
		}
	}

	/// Emergency function to pause buy-in and finalisation.
	function setHalted(bool _halted)
		public
		only_admin
	{ 
		halted = _halted;
	}

	/// Emergency function to drain the contract of any funds.
	function drain()
		public
		only_admin
	{
		require(treasury.transfer(this.balance));
	}

	/// Kill this contract once the sale is finished.
	function kill()
		public
		when_all_finalised
	{
		suicide(admin);
	}

	/// The current price for a single token. If a buyin happens now, this is
	/// the highest price per token that the buyer will pay.
	function currentPrice()
		constant
	   	public
		returns (uint weiPerToken)
	{
		if (!isActive()) return 0;
		return beginPrice - (now - beginTime) * saleSpeed;
	}

	/// Returns the tokens available for purchase right now.
	function tokensAvailable()
		constant
		public
		returns (uint tokens)
	{
		if (!isActive()) return 0;
		return tokenCap - totalReceived / currentPrice();
	}

	/// The largest purchase than can be made at present.
	function maxPurchase()
		constant
		public
		returns (uint spend)
	{
		if (!isActive()) return 0;
		return tokenCap * currentPrice() - totalReceived;
	}

	/// True if the sale is ongoing.
	function isActive()
		constant
		public
		returns (bool)
	{
		return now >= beginTime && now < endTime;
	}

	/// True if all participants have finalised.
	function allFinalised()
		constant
		public
		returns (bool)
	{
		return now >= endTime && totalReceived == totalFinalised;
	}

	/// Ensure the sale is ongoing.
	modifier when_active
	{
		require(isActive());
		_;
	}
	
	/// Ensure the sale is ended.
	modifier when_ended
	{
		require(now >= endTime);
		_;
	}
	
	/// Ensure we're not halted.
	modifier when_not_halted
	{
		assert(!halted);
		_;
	}
	
	/// Ensure all participants have finalised.
	modifier when_all_finalised
	{
		require(allFinalised());
		_;
	}
	
	/// Ensure the sender sent a sensible amount of ether.
	modifier avoid_dust
	{
		require(msg.value >= DUST_LIMIT);
		_;
	}
	
	/// Ensure `_who` is a participant.
	modifier only_participants(address _who)
	{
		require(participants[_who] != 0);
		_;
	}
	
	/// Ensure sender is admin.
	modifier only_admin
	{
		require(msg.sender == admin);
		_;
	}
	
	/// Ensure sender is treasury
	modifier only_treasury
	{
		require(msg.sender == treasury);
		_;
	}

	// State:

	/// The auction participants.
	mapping (address => uint) public participants;
	mapping (address => uint) public refundBalances;
	mapping (address => uint) public tokenBalances;
	mapping (address => uint) public treasuryBalance;

	/// Total amount of ether received.
	uint public totalReceived = 0;

	/// Total amount of ether which has been finalised.
	uint public totalFinalised = 0;

	/// The current end time. Gets updated when new funds are received.
	uint public endTime;

	/// The price per token; only valid once the sale has ended and at least one
	/// participant has finalised.
	uint public endPrice;

	/// Must be false for any public function to be called.
	bool public halted;

	// Constants after constructor:

	/// The tokens contract.
	Token public tokenContract;

	/// The treasury address; where all the Ether goes.
	address public treasury;

	/// The admin address; auction can be paused or halted at any time by this.
	address public admin;

	/// The time at which the sale begins.
	uint public beginTime;

	/// Price at which the sale begins.
	uint public beginPrice;

	/// The speed at which the price reduces, in Wei per second.
	uint public saleSpeed;

	/// Maximum amount of tokens to mint. Once totalSale / currentPrice is
	/// greater than this, the sale ends.
	uint public tokenCap;

	// Static constants:

	/// Anything less than this is considered dust and cannot be used to buy in.
	uint constant public DUST_LIMIT = 10 finney;
}
