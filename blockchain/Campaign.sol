// SPDX-License-Identifier: BSD-2-Clause-Patent

pragma solidity ^0.8.14;

//todo: запасной аккаунт
contract Campaign {
    
    // internal structs

    struct Request {
        bool IsActive;

        uint Sum;
        address Recipient;

        mapping(address => bool) AcceptedBy;
        uint64 AcceptancesCount;
    }

    // public structs

    struct RequestResponse {
        bool IsActive;

        uint Sum;
        address Recipient;
        uint64 AcceptancesCount;
    }

    // properties

    bool public IsActive;
    address public Creator;

    string public Name;
    string public Description;
    bytes public Avatar;

    mapping(address => uint) private Contributors;
    uint64 public ContributorsCount;

    uint public ExpectedGoal;
    uint public Received;
    uint8 public RequestAcceptanceThreshold;
    uint32 MinAcceptancesForRequestExecution;
    uint8 public OnLeaveCommission;

    Request[] private _requests;
    string[] private _suggestions;
    
    //

    constructor(
        address creator,
        string memory name,
        string memory description,
        bytes memory avatar,
        uint expectedGoal,
        uint8 requestAcceptanceThreshold /*percents*/,
        uint32 minAcceptancesForRequestExecution,
        uint8 onLeaveCommission /*percents*/)
    {
        IsActive = true;
        Creator = creator;

        Name = name;
        Description = description;
        Avatar = avatar;

        ExpectedGoal = expectedGoal;
        Received = 0;
        RequestAcceptanceThreshold = requestAcceptanceThreshold;
        MinAcceptancesForRequestExecution = minAcceptancesForRequestExecution;
        OnLeaveCommission = onLeaveCommission;
    }

    // membership methods

    function contribute()
    public
    payable
    campaignIsActive
    {
        require(msg.value != 0, "This operation requires money transfer");
        //todo: проверить, работает ли если сохранить в storage
        if (Contributors[msg.sender] == 0)
            ContributorsCount += 1;

        Contributors[msg.sender] += msg.value;
    }

    function leave()
    public
    payable
    campaignIsActive
    onlyContributorAllowed
    {
        uint donation = Contributors[msg.sender];
        uint commission = donation * OnLeaveCommission / 100;
        payable(msg.sender).transfer(donation - commission);

        Contributors[msg.sender] = 0;
        ContributorsCount -= 1;
    }

    // requests

    function createRequest(
        uint sum,
        address recipient
    )
    public
    campaignIsActive
    onlyCreatorAllowed
    {
        Request storage request = _requests.push();

        request.IsActive = true;
        request.AcceptancesCount = 0;

        request.Sum = sum;
        request.Recipient = recipient;
    }

    function closeRequest(uint requestIndex)
    public
    campaignIsActive
    onlyCreatorAllowed
    requestExists(requestIndex)
    {
        _requests[requestIndex].IsActive = false;
    }

    function acceptRequest(uint requestIndex)
    public
    campaignIsActive
    onlyContributorAllowed
    requestExists(requestIndex)
    requestIsActive(requestIndex)
    {
        Request storage request = _requests[requestIndex];

        require(request.AcceptedBy[msg.sender] == false, "Already accepted");

        request.AcceptedBy[msg.sender] = true;
        request.AcceptancesCount += 1;
    }

    function runRequestExecution(uint requestIndex)
    public
    payable
    campaignIsActive
    onlyCreatorAllowed
    requestExists(requestIndex)
    requestIsActive(requestIndex)
    {
        Request storage request = _requests[requestIndex];

        require(request.AcceptancesCount >= MinAcceptancesForRequestExecution, "Not enough acceptances");
        require(request.Sum <= address(this).balance, "Not enough funds");
        require(
            request.AcceptancesCount * 100 / ContributorsCount >= RequestAcceptanceThreshold,
            "Acceptance threshold not passed yet");

        payable(request.Recipient).transfer(request.Sum);
        request.IsActive = false;
    }

    function getRequests(uint skip, uint take)
    public
    view
    returns (RequestResponse[] memory)
    {
        if (skip >= _requests.length)
            return new RequestResponse[](0);

        if (take > _requests.length - skip)
            take = _requests.length - skip;
        RequestResponse[] memory requestsResponse = new RequestResponse[](take);

        uint pos = 0;
        for (uint index = skip; index < skip + take; ++index)
        {
            Request storage request = _requests[index];

            requestsResponse[0] = RequestResponse({
                IsActive: request.IsActive,
                Sum: request.Sum,
                Recipient: request.Recipient,
                AcceptancesCount: request.AcceptancesCount
            });

            ++pos;
        }

        return requestsResponse;
    }

    // suggestions

    function suggest(string memory suggestion)
    public
    {
        _suggestions.push(suggestion);
    }

    function getSuggestions(uint skip, uint take)
    public
    view
    returns (string[] memory)
    {
        if (skip >= _requests.length)
            return new string[](0);

        if (take > _suggestions.length - skip)
            take = _suggestions.length - skip;
        string[] memory suggestionsResponse = new string[](take);

        uint pos = 0;
        for (uint index = skip; index < skip + take; ++index)
            suggestionsResponse[index] = _suggestions[pos++];

        return suggestionsResponse;
    }

    // modifiers

    modifier campaignIsActive()
    {
        require(IsActive == true, "Campaign is closed");
        _;
    }

    modifier onlyCreatorAllowed()
    {
        require(msg.sender == Creator, "Only manager allowed");
        _;
    }

    modifier onlyContributorAllowed()
    {
        require(Contributors[msg.sender] != 0, "You are not in contributors list");
        _;
    }

    modifier requestExists(uint requestIndex)
    {
        require(_requests.length >= requestIndex, "Request not found");
        _;
    }

    modifier requestIsActive(uint requestIndex)
    {
        require(_requests[requestIndex].IsActive, "Request closed");
        _;
    }
}