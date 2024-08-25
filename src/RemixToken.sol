// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ERC6909} from "lib/solady/src/tokens/ERC6909.sol";

struct Layer {
    Mix mType;
    address artist;
    string name;
    string symbol;
    string work;
}

struct Curve {
    uint256 supply;
    uint256 maxSupply;
    uint64 scale;
    uint32 constant_a;
    uint32 constant_b;
    uint32 constant_c;
}

enum Mix {
    OPEN,
    TOKEN
}

/// @title Remix
/// @notice A database management system to log remix artwork from interacting with Bulletin.
/// @author audsssy.eth
contract RemixToken is ERC6909 {
    event LayerAdded(
        Mix indexed mType,
        address artist,
        string name,
        string symbol,
        string work
    );
    event CurveAdded(
        uint256 indexed maxSupply,
        uint64 scale,
        uint32 constant_a,
        uint32 constant_b,
        uint32 constant_c
    );
    event Supported(uint256 indexed layerId, address supporter, uint256 price);

    error ExceedLimit();
    error InvalidLayer();
    error InvalidAmount();
    error InvalidFormula();

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    uint256 public constant ROYALTIES = 10;

    uint256 public layerId;

    // Mapping of remixes by layerId.
    // layerId => Layer
    mapping(uint256 => Layer) public layers;

    // Mapping of previous layers by layerIds.
    // layerId => layerIds
    mapping(uint256 => uint256[]) public credits;

    // Mapping of previous layers by layerIds.
    // layerId => Curve
    mapping(uint256 => Curve) public curves;

    /// -----------------------------------------------------------------------
    /// Constructor & Modifier
    /// -----------------------------------------------------------------------

    constructor(
        string memory _name,
        string memory _symbol,
        string memory work,
        uint256 maxSupply,
        uint64 scale,
        uint32 constant_a,
        uint32 constant_b,
        uint32 constant_c
    ) {
        // Store first layer.
        layers[0] = Layer({
            mType: Mix.TOKEN,
            artist: msg.sender,
            name: _name,
            symbol: _symbol,
            work: work
        });

        _curve(maxSupply, scale, constant_a, constant_b, constant_c);
    }

    function name(uint256 id) public view override returns (string memory n) {
        (, n, , ) = getLayer(id);
    }

    function symbol(uint256 id) public view override returns (string memory s) {
        (, , s, ) = getLayer(id);
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        string
            memory header = '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" style="background:#FFFBF5">';
        string memory footer = "</svg>";
        string memory uri;

        uint256[] memory ids = credits[id];
        uint256 length = ids.length;

        Layer memory _layer;

        for (uint256 i; i < length; ++i) {
            _layer = layers[ids[i]];

            uri = concat(uri, _layer.work);
        }

        uri = concat(uri, layers[id].work);

        return string.concat(header, uri, footer);
    }

    function concat(
        string memory a,
        string memory b
    ) private pure returns (string memory) {
        return string.concat(a, b);
    }

    function getLayer(
        uint256 id
    )
        public
        view
        returns (address, string memory, string memory, string memory)
    {
        Layer memory _layer = layers[id];
        return (_layer.artist, _layer.name, _layer.symbol, _layer.work);
    }

    /// -----------------------------------------------------------------------
    /// Mix Logic
    /// -----------------------------------------------------------------------

    /// @notice Open mixing.
    function mix(
        uint256 id,
        string calldata _name,
        string calldata _symbol,
        string calldata work,
        uint256 maxSupply,
        uint64 scale,
        uint32 constant_a,
        uint32 constant_b,
        uint32 constant_c
    ) external payable {
        if (id > layerId) revert InvalidLayer();
        _mix(id, Mix.OPEN, msg.sender, _name, _symbol, work);
        _curve(maxSupply, scale, constant_a, constant_b, constant_c);
    }

    /// @notice Token mixing.
    function mixByToken(
        uint256 id,
        string calldata _name,
        string calldata _symbol,
        string calldata work,
        uint256 maxSupply,
        uint64 scale,
        uint32 constant_a,
        uint32 constant_b,
        uint32 constant_c
    ) external payable {
        // Check user token balance.
        if (balanceOf(msg.sender, id) == 0) revert InsufficientBalance();
        _mix(id, Mix.TOKEN, msg.sender, _name, _symbol, work);
        _curve(maxSupply, scale, constant_a, constant_b, constant_c);
        _burn(msg.sender, id, 1);
    }

    function _mix(
        uint256 id,
        Mix mType,
        address artist,
        string calldata _name,
        string calldata _symbol,
        string calldata work
    ) internal {
        unchecked {
            ++layerId;
        }

        // Store new layer.
        layers[layerId] = Layer({
            mType: mType,
            artist: artist,
            name: _name,
            symbol: _symbol,
            work: work
        });

        if (id > 0) {
            // Add all artists of previous layers to credits mapping per new layer.
            uint256[] memory _credits = credits[id];
            uint256 length = _credits.length;

            for (uint256 i; i < length; ++i) {
                credits[layerId].push(_credits[i]);
            }

            credits[layerId].push(id);
        } else {
            // Add layer 0.
            credits[layerId].push(0);
        }

        emit LayerAdded(mType, artist, _name, _symbol, work);
    }

    /// -----------------------------------------------------------------------
    /// Curve Logic
    /// -----------------------------------------------------------------------

    function _curve(
        uint256 maxSupply,
        uint64 scale,
        uint32 constant_a,
        uint32 constant_b,
        uint32 constant_c
    ) internal {
        curves[layerId] = Curve({
            supply: 0,
            maxSupply: maxSupply,
            scale: scale,
            constant_a: constant_a,
            constant_b: constant_b,
            constant_c: constant_c
        });
        emit CurveAdded(maxSupply, scale, constant_a, constant_b, constant_c);
    }

    function calculatePrice(uint256 _layerId) public view returns (uint256) {
        Curve memory curve = curves[_layerId];
        if (curve.supply + 1 > curve.maxSupply) revert ExceedLimit();

        return
            curve.constant_a *
            (curve.supply ** 2) *
            curve.scale +
            curve.constant_b *
            curve.supply *
            curve.scale +
            curve.constant_c *
            curve.scale;
    }

    function support(uint256 _layerId) public payable {
        uint256[] memory ids = credits[_layerId];
        uint256 length = ids.length;

        Layer memory _layer;
        uint256 slices;

        // Calculate total number of slices.
        unchecked {
            for (uint256 i; i < length; ++i) {
                _layer = layers[ids[i]];
                (_layer.mType == Mix.TOKEN) ? ++slices : slices;
            }
        }

        // Calculate royalties per slice.
        uint256 price = calculatePrice(_layerId);
        if (price != msg.value) revert InvalidAmount();
        uint256 royalties = ((price * ROYALTIES) / 100);
        uint256 royaltiesBySlice;

        unchecked {
            if (slices == 0) {
                _layer = layers[_layerId];
                safeTransferETH(_layer.artist, price);
            } else {
                royaltiesBySlice = royalties / slices;

                // Transfer royalties to all previous artists.
                for (uint256 i; i < length; ++i) {
                    _layer = layers[ids[i]];

                    if (_layer.mType == Mix.TOKEN) {
                        safeTransferETH(_layer.artist, royaltiesBySlice);
                    }
                }
                // Transfer residual to artist of instant layer.
                _layer = layers[_layerId];
                safeTransferETH(_layer.artist, price - royalties);
            }
        }

        // Mint to msg.sender.
        _mint(msg.sender, _layerId, 1);

        unchecked {
            ++curves[_layerId].supply;
        }

        emit Supported(_layerId, msg.sender, price);
    }
}

/// @dev Solady
function safeTransferETH(address to, uint256 amount) {
    assembly ("memory-safe") {
        if iszero(call(gas(), to, amount, codesize(), 0x00, codesize(), 0x00)) {
            mstore(0x00, 0xb12d13eb)
            revert(0x1c, 0x04)
        }
    }
}
