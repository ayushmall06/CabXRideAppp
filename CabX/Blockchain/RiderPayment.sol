pragma solidity >=0.7.0 <0.9.0;

contract RidePayment {
    address payable rider;               // Rider address
    address payable driver;              // Driver address
    uint public TripDist;                // Distance Covered
    uint expirationReturn = block.timestamp + 10

    event Sent(address from, address to, uint amount);

    // Constructor
    constructor(RidePayment _driver, uint _TripDist) payable {
        driver = _driver
        TripDist = _TripDist
    }

    function proofOfDistanceElapsedDist(uint elapsedDist, uint amount) {
        // if this is called with the rider, the driver gets paid.
        if(msg.sender != rider) return;
        emit Sent(msg.sender, receiver, 0.3*amount);
        
        while(true) {
            if(elapsedDist == TripDist)
            {
                emit Sent(msg.sender, receiver, 0.7*amount);
                break;
            }
        }
    }

    function withDrawFunds(uint amount) {
        // issue a refund back to the rider if the timeout has expired.
        if ( block.timestamp < expirationReturn) return;
        if(msg.sender != rider) return;
        emit sent(receiver, sender, 0.3*amount);
    }
}
