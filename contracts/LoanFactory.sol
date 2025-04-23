// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

error NotApproved();
error NotOwner();
error NotExists();

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./BokkyPooBahsRedBlackTreeLibrary.sol";

contract LoanFactory is ERC721 {
    using Strings for uint256;
    using BokkyPooBahsRedBlackTreeLibrary for BokkyPooBahsRedBlackTreeLibrary.Tree;

    uint256 public loanIDCounter = 1;

    struct LoanDetails {
        uint256 faceAmount;
        uint256 discount; // Stored in basis points (1% = 100 basis points)
        uint256 snowballID;
        address owner;
    }

    mapping(uint256 => LoanDetails) public Loans;
    mapping(uint256 => uint256[]) public amountToLoanIDs;
    BokkyPooBahsRedBlackTreeLibrary.Tree private loanTree;

    address public workingCapitalProvider;
    address public snowballAddress;

    modifier onlyWCProvider() {
        require(msg.sender == workingCapitalProvider, "Not approved");
        _;
    }

    modifier onlySnowball() {
        require(msg.sender == snowballAddress, "Not approved");
        _;
    }

    constructor(
        address _workingCapitalProvider,
        address _snowballAddress
    ) ERC721("SnowballWorkingCapital", "SBWC") {
        workingCapitalProvider = _workingCapitalProvider;
        snowballAddress = _snowballAddress;
    }

    function mint(
        uint256 _faceAmount,
        uint256 _discount,
        uint256 _snowballID,
        address _owner
    ) external onlyWCProvider returns (uint256) {
        Loans[loanIDCounter] = LoanDetails({
            faceAmount: _faceAmount,
            discount: _discount,
            snowballID: _snowballID,
            owner: _owner
        });

        _mint(_owner, loanIDCounter);
        if (!loanTree.exists(_faceAmount)) {
            loanTree.insert(_faceAmount);
        }
        amountToLoanIDs[_faceAmount].push(loanIDCounter);
        loanIDCounter += 1;
        return (loanIDCounter - 1);
    }

    function UpdateLoanAmount(
        uint256 loanID,
        uint256 subtractAmount
    ) external onlySnowball {
        Loans[loanID].faceAmount -= subtractAmount;
    }

    function transferLoan(uint256 loanID, address newOwner) public {
        LoanDetails storage loan = Loans[loanID];
        // Ensure the caller is the current owner of the loan
        if (loan.owner != msg.sender) {
            revert NotOwner();
        }

        // Transfer the ownership of the loan to the new owner
        loan.owner = newOwner;

        // Transfer the SWBC token ownership to the new owner
        _transfer(msg.sender, newOwner, loanID);
    }

    function burnToken(uint256 tokenID) external onlySnowball {
        //Burn token
        _burn(tokenID);

        //Remove loan from amount tree
        uint256[] storage loansAtAmount = amountToLoanIDs[
            Loans[tokenID].faceAmount
        ];
        if (loansAtAmount.length == 1) {
            delete amountToLoanIDs[Loans[tokenID].faceAmount];
            loanTree.remove(Loans[tokenID].faceAmount);
        } else {
            for (uint256 i = 0; i < loansAtAmount.length; i++) {
                if (loansAtAmount[i] == tokenID) {
                    loansAtAmount[i] = loansAtAmount[loansAtAmount.length - 1];
                    loansAtAmount.pop();
                    break;
                }
            }
        }

        //Remove loan from Loans mapping
        delete Loans[tokenID];
    }

    function getActiveLoans(
        uint256 numberToReturn
    ) public view returns (uint256[] memory) {
        uint256[] memory loanIDs = new uint256[](numberToReturn);
        uint256 count = 0;
        uint256 currentKey = loanTree.first();

        while (
            count < numberToReturn &&
            currentKey != BokkyPooBahsRedBlackTreeLibrary.getEmpty()
        ) {
            uint256[] storage loans = amountToLoanIDs[currentKey];
            for (
                uint256 i = 0;
                i < loans.length && count < numberToReturn;
                i++
            ) {
                loanIDs[count] = loans[i];
                count++;
            }
            currentKey = loanTree.next(currentKey);
        }

        // If we didn't fill the entire array, we need to trim it
        if (count < numberToReturn) {
            uint256[] memory trimmedLoanIDs = new uint256[](count);
            for (uint256 i = 0; i < count; i++) {
                trimmedLoanIDs[i] = loanIDs[i];
            }
            return trimmedLoanIDs;
        }

        return loanIDs;
    }

    // Function to get a specific range active requests in order of their discounts from largest to smallest
    function getActiveLoansRange(
        uint256 start,
        uint256 end
    ) public view returns (uint256[] memory) {
        require(start <= end, "Start must be less than or equal to end");

        uint256[] memory loanIDs = new uint256[](end - start + 1);
        uint256 count = 0;
        uint256 currentKey = loanTree.last();
        uint256 totalProcessed = 0;

        while (count < (end - start + 1) && currentKey != 0) {
            uint256[] storage loans = amountToLoanIDs[currentKey];
            for (uint256 i = 0; i < loans.length; i++) {
                if (totalProcessed >= start && totalProcessed <= end) {
                    loanIDs[count] = loans[i];
                    count++;
                }
                totalProcessed++;
                if (count == (end - start + 1)) {
                    break;
                }
            }
            currentKey = loanTree.prev(currentKey);
        }

        // If we didn't fill the entire array, we need to trim it
        if (count < (end - start + 1)) {
            uint256[] memory trimmedLoanIDs = new uint256[](count);
            for (uint256 i = 0; i < count; i++) {
                trimmedLoanIDs[i] = loanIDs[i];
            }
            return trimmedLoanIDs;
        }

        return loanIDs;
    }

    function tokenURI(
        uint256 tokenID
    ) public view override returns (string memory) {
        LoanDetails memory loan = Loans[tokenID];
        require(loan.faceAmount != 0, "Does not exist");
        string memory svg = generateSVG(
            Loans[tokenID].snowballID,
            Loans[tokenID].discount,
            tokenID
        );

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "Snowball Working Capital",',
                        '"description": "Snowball ID: ',
                        loan.snowballID.toString(),
                        ", Discount: ",
                        (loan.discount / 100).toString(),
                        ".",
                        (loan.discount % 100).toString(),
                        "%, Amount: ",
                        loan.faceAmount.toString(),
                        '",',
                        '"image": "data:image/svg+xml;base64,',
                        Base64.encode(bytes(svg)),
                        '"}'
                    )
                )
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    function generateSVG(
        uint256 _snowballID,
        uint256 _discount,
        uint256 _loanID
    ) internal pure returns (string memory) {
        string memory svg = string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 480">',
                "<style>",
                ".tokens { font: bold 15px sans-serif; }",
                ".underlying { font: normal 15px sans-serif; }",
                ".discount { font: normal 15px sans-serif; }",
                "</style>",
                '<rect width="300" height="480" fill="hsl(560,80%,40%)" />',
                '<rect x="30" y="30" width="240" height="420" rx="15" ry="15" fill="hsl(550,90%,50%)" stroke="#000" />',
                '<rect x="30" y="87" width="240" height="42" />',
                '<text x="39" y="105" class="tokens" fill="#fff">',
                "Snowball Working Capital",
                '<tspan x="39" dy="20">Loan ID: ',
                _loanID.toString(),
                "</tspan>",
                "</text>",
                '<rect x="30" y="135" width="240" height="30" />',
                '<text x="39" y="155" class="underlying" fill="#fff">',
                "Underlying Snowball ID: ",
                _snowballID.toString(),
                "</text>",
                '<rect x="30" y="342" width="240" height="24" />',
                '<text x="39" y="360" class="discount" fill="#fff">',
                "Discount: ",
                (_discount / 100).toString(),
                ".",
                (_discount % 100).toString(),
                "%",
                "</text>",
                "</svg>"
            )
        );

        return svg;
    }
}
