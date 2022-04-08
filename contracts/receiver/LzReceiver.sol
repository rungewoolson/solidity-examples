pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/ILayerZeroReceiver.sol";
import "../interfaces/ILayerZeroUserApplicationConfigV2.sol";
import "../interfaces/ILayerZeroEndpoint.sol";

/*
* a generic LzReceiver implementation
*/
abstract contract LzReceiver is Ownable, ILayerZeroReceiver, ILayerZeroUserApplicationConfigV2 {
    ILayerZeroEndpoint public endpoint;

    mapping(uint16 => bytes) public trustedSourceLookup;

    function lzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) external override {
        // lzReceive must be called by the endpoint for security
        require(_msgSender() == address(endpoint));
        // if will still block the message pathway from (srcChainId, srcAddress). should not receive message from untrusted remote.
        require(_srcAddress.length == trustedSourceLookup[_srcChainId].length && keccak256(_srcAddress) == keccak256(trustedSourceLookup[_srcChainId]), "LzReceiver: invalid source sending contract");

        _LzReceive(_srcChainId, _srcAddress, _nonce, _payload);
    }

    // abstract function
    function _LzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) virtual internal;

    function _lzSend(uint16 _dstChainId, bytes memory _payload, address payable _refundAddress, address _zroPaymentAddress, bytes memory _txParam) internal {
        endpoint.send{value: msg.value}(_dstChainId, trustedSourceLookup[_dstChainId], _payload, _refundAddress, _zroPaymentAddress, _txParam);
    }

    //---------------------------DAO CALL----------------------------------------
    // generic config for user Application
    function setConfig(uint16 _version, uint16 _chainId, uint256 _configType, bytes calldata _config) external override onlyOwner {
        endpoint.setConfig(_version, _chainId, _configType, _config);
    }

    function setSendVersion(uint16 _version) external override onlyOwner {
        endpoint.setSendVersion(_version);
    }

    function setReceiveVersion(uint16 _version) external override onlyOwner {
        endpoint.setReceiveVersion(_version);
    }

    function forceResumeReceive(uint16 _srcChainId, bytes calldata _srcAddress) external override onlyOwner {
        endpoint.forceResumeReceive(_srcChainId, _srcAddress);
    }

    // allow owner to set it multiple times.
    function setTrustedSource(uint16 _srcChainId, bytes calldata _srcAddress) external override onlyOwner {
        trustedSourceLookup[_srcChainId] = _srcAddress;
        emit SetTrustedSource(_srcChainId, _srcAddress);
    }

    function isTrustedSource(uint16 _srcChainId, bytes calldata _srcAddress) external override view returns(bool) {
        bytes memory trustedSource  = trustedSourceLookup[_srcChainId];
        return keccak256(trustedSource) == keccak256(_srcAddress);
    }
}