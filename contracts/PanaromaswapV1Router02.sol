pragma solidity =0.6.6;

import '@panaromafinance/panaromaswap_v1core/contracts/interfaces/IPanaromaswapV1Factory.sol';
import './TransferHelper.sol';

import './interfaces/IPanaromaswapV1Router02.sol';
import './libraries/PanaromaswapV1Library.sol';
import './interfaces/IERC20.sol';
import './interfaces/IWETH.sol';

interface IvalidationStorageFactory {
    function getUserInfo(address ) external returns(address);
}

interface IvalidationStorage {
    function checkAnalysis(address ) external view returns(address, string memory, uint256, uint);
}

contract PanaromaswapV1Router02 is IPanaromaswapV1Router02 {
    using SafeMath for uint;

    address public immutable override factory;
    address public immutable override WETH;
    address public lockContract;
    address public feeTo;
    address public ptoken;
    address public refWalletFactory;
    //0x2c0948EC0ABb380e74DA5c9bC78514C576F5c162
    address private checkValidation;
    //0x4f5aE21Ca1d07E7d05A86f0a44369D5232173308

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'PanaromaswapV1Router: EXPIRED');
        _;
    }

    constructor(address _factory, address _WETH, address _lockContract, 
                address _feeTo, address _ptoken, address _refWalletFactory,
                address _checkValidation) public {
        factory = _factory;
        WETH = _WETH;
        lockContract = _lockContract;
        feeTo = _feeTo;
        ptoken = _ptoken;
        checkValidation = _checkValidation;
        refWalletFactory = _refWalletFactory;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal virtual returns (uint amountA, uint amountB) {
        // create the pair if it doesn't exist yet
        if (IPanaromaswapV1Factory(factory).getPair(tokenA, tokenB) == address(0)) {
            IPanaromaswapV1Factory(factory).createPair(tokenA, tokenB);
        }
        (uint reserveA, uint reserveB) = PanaromaswapV1Library.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = PanaromaswapV1Library.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'PanaromaswapV1Router: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = PanaromaswapV1Library.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'PanaromaswapV1Router: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        require(_checkValidation(msg.sender) == true);
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = PanaromaswapV1Library.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IPanaromaswapV1Pair(pair).mint(to);
    }

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity) {
        require(_checkValidation(msg.sender) == true);
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        address pair = PanaromaswapV1Library.pairFor(factory, token, WETH);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pair, amountETH));
        liquidity = IPanaromaswapV1Pair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountA, uint amountB) {
        address pair = PanaromaswapV1Library.pairFor(factory, tokenA, tokenB);
        IPanaromaswapV1Pair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint amount0, uint amount1) = IPanaromaswapV1Pair(pair).burn(to);
        (address token0,) = PanaromaswapV1Library.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'PanaromaswapV1Router: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'PanaromaswapV1Router: INSUFFICIENT_B_AMOUNT');
    }
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountToken, uint amountETH) {
        (amountToken, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountA, uint amountB) {
        address pair = PanaromaswapV1Library.pairFor(factory, tokenA, tokenB);
        uint value = approveMax ? uint(-1) : liquidity;
        IPanaromaswapV1Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountToken, uint amountETH) {
        address pair = PanaromaswapV1Library.pairFor(factory, token, WETH);
        uint value = approveMax ? uint(-1) : liquidity;
        IPanaromaswapV1Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountETH) {
        (, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountETH) {
        address pair = PanaromaswapV1Library.pairFor(factory, token, WETH);
        uint value = approveMax ? uint(-1) : liquidity;
        IPanaromaswapV1Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
            token, liquidity, amountTokenMin, amountETHMin, to, deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = PanaromaswapV1Library.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? PanaromaswapV1Library.pairFor(factory, output, path[i + 2]) : _to;
            IPanaromaswapV1Pair(PanaromaswapV1Library.pairFor(factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        require(_checkValidation(msg.sender) == true);
        amounts = PanaromaswapV1Library.getAmountsOut(factory, amountIn, path);
        require((amounts[amounts.length - 1]) >= amountOutMin, 'PanaromaswapV1Router: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, PanaromaswapV1Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
        refPlanTokensForTokens(path, amountIn);
    }
    function swap_(address[] memory path, address _to) private {

            (address input, address output) = (path[0], ptoken);
            (address token0, ) = PanaromaswapV1Library.sortTokens(input, output);
            IPanaromaswapV1Pair pair = IPanaromaswapV1Pair(PanaromaswapV1Library.pairFor(factory, input, output));
            uint256 amountInput;
            uint256 amountOutput;
            // scope to avoid stack too deep errors
            {
                (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
                (uint256 reserveInput, uint256 reserveOutput) =
                    input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
                amountOutput = PanaromaswapV1Library.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            (uint256 amount0Out, uint256 amount1Out) =
                input == token0 ? (uint256(0), amountOutput) : (amountOutput, uint256(0));
            pair.swap(amount0Out, amount1Out, _to, new bytes(0));

    }
    function swapETH_(address _to) private {
            (address input, address output) = (WETH, ptoken);
            (address token0, ) = PanaromaswapV1Library.sortTokens(input, output);
            IPanaromaswapV1Pair pair = IPanaromaswapV1Pair(PanaromaswapV1Library.pairFor(factory, input, output));
            uint256 amountInput;
            uint256 amountOutput;
            // scope to avoid stack too deep errors
            {
                (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
                (uint256 reserveInput, uint256 reserveOutput) =
                    input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
                amountOutput = PanaromaswapV1Library.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            (uint256 amount0Out, uint256 amount1Out) =
                input == token0 ? (uint256(0), amountOutput) : (amountOutput, uint256(0));
            pair.swap(amount0Out, amount1Out, _to, new bytes(0));
    }
    //////////////////updated///////////////
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        require(_checkValidation(msg.sender) == true);
        amounts = PanaromaswapV1Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'PanaromaswapV1Router: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, PanaromaswapV1Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
        refPlanTokensForETH(path, amounts[0]);
    }

    ////////updated///////////
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(_checkValidation(msg.sender) == true);
        require(path[0] == WETH, 'PanaromaswapV1Router: INVALID_PATH');
        amounts = PanaromaswapV1Library.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'PanaromaswapV1Router: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).deposit{value: (amounts[0])}();
        assert(IWETH(WETH).transfer(PanaromaswapV1Library.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        refPlanETHForToken(msg.value);
    }

    ////////updated///////////
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(_checkValidation(msg.sender) == true);
        require(path[path.length - 1] == WETH, 'PanaromaswapV1Router: INVALID_PATH');
        amounts = PanaromaswapV1Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0]+(amounts[0]/1000) <= amountInMax, 'PanaromaswapV1Router: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, PanaromaswapV1Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
        refPlanTokensForETH(path, amounts[0]);
    }

    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(_checkValidation(msg.sender) == true);
        require(path[path.length - 1] == WETH, 'PanaromaswapV1Router: INVALID_PATH');
        amounts = PanaromaswapV1Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'PanaromaswapV1Router: INSUFFICIENT_OUTPUT_AMOUNT');
        //path[0] = AVIL,  AVIL goes to lpool
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, PanaromaswapV1Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        // weth amounts, path[i] AVIL, path[i-1] weth, address(this) router
        _swap(amounts, path, address(this));
        //WETH recieved by router amounts[amounts.length - 1] i.e. eth amount input
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        //eth from router to reciever 
        TransferHelper.safeTransferETH(to, (amounts[amounts.length - 1]));
        refPlanTokensForETH(path, amountIn);
    }

    ///////////updated//////////////
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(_checkValidation(msg.sender) == true);
        require(path[0] == WETH, 'PanaromaswapV1Router: INVALID_PATH');
        amounts = PanaromaswapV1Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0]+(amounts[0]/1000) <= msg.value, 'PanaromaswapV1Router: EXCESSIVE_INPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(PanaromaswapV1Library.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        refPlanETHForToken(amounts[0]);
        //refund dust
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0] - (amounts[0]/1000));
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
            (address input, address output) = (path[0], ptoken);
            (address token0, ) = PanaromaswapV1Library.sortTokens(input, output);
            IPanaromaswapV1Pair pair = IPanaromaswapV1Pair(PanaromaswapV1Library.pairFor(factory, input, output));
            uint256 amountInput;
            uint256 amountOutput;
            // scope to avoid stack too deep errors
            {
                (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
                (uint256 reserveInput, uint256 reserveOutput) =
                    input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
                amountOutput = PanaromaswapV1Library.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            (uint256 amount0Out, uint256 amount1Out) =
                input == token0 ? (uint256(0), amountOutput) : (amountOutput, uint256(0));
            pair.swap(amount0Out, amount1Out, _to, new bytes(0));
    }
    function swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = PanaromaswapV1Library.sortTokens(input, output);
            IPanaromaswapV1Pair pair = IPanaromaswapV1Pair(PanaromaswapV1Library.pairFor(factory, input, output));
            uint amountInput;
            uint amountOutput;
            { // scope to avoid stack too deep errors
            (uint reserve0, uint reserve1,) = pair.getReserves();
            (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
            amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
            amountOutput = PanaromaswapV1Library.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? PanaromaswapV1Library.pairFor(factory, output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) {
        require(_checkValidation(msg.sender) == true);
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, PanaromaswapV1Library.pairFor(factory, path[0], path[1]), amountIn
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        swapSupportingFeeOnTransferTokens(path, to);
        require(
            (IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore))
            >= amountOutMin,
            'PanaromaswapV1Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
        refPlanTokenForTokenSupportingFee(path, amountIn);
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        override
        payable
        ensure(deadline)
    {
        require(_checkValidation(msg.sender) == true);
        require(path[0] == WETH, 'PanaromaswapV1Router: INVALID_PATH');
        uint amountIn = msg.value;
        IWETH(WETH).deposit{value: amountIn}();
        assert(IWETH(WETH).transfer(PanaromaswapV1Library.pairFor(factory, path[0], path[1]), amountIn));
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        swapSupportingFeeOnTransferTokens(path, to);
        require(
            (IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore)) 
            >= amountOutMin,
            'PanaromaswapV1Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
        refPlanETHForTokenSupportingFee(amountIn);
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        override
        ensure(deadline)
    {
        require(_checkValidation(msg.sender) == true);
        require(path[path.length - 1] == WETH, 'PanaromaswapV1Router: INVALID_PATH');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, PanaromaswapV1Library.pairFor(factory, path[0], path[1]), amountIn
        );
        swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(WETH).balanceOf(address(this));
        require(amountOut >= amountOutMin, 'PanaromaswapV1Router: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
        refPlanTokenForETHSupportingFee(path, amountIn);
    }

    function refPlanTokensForTokens(address[] memory path, uint amountIn) internal virtual{
        uint n = 1;
        uint m = 10;
        (address input, address output) = (path[0] == ptoken)?(ptoken, path[1]):(path[0], ptoken);
        (address __pair, address __parent) = getParentPair(msg.sender);
        {
            
            for(n =1;n<4;n++){
               if(__parent == address(0) ){
                if(m<5) m=m-1;
                    TransferHelper.safeTransferFrom(
                        input, msg.sender, PanaromaswapV1Library.pairFor(factory, input, output), (amountIn*m)/10000
                    );
                    if(input != ptoken) swap_(path, feeTo);
                n=4;
               }else{
                m=m-(m/2);
                    TransferHelper.safeTransferFrom(
                        input, msg.sender, PanaromaswapV1Library.pairFor(factory, input, output), (amountIn*m)/10000
                    );
                    if(input != ptoken) swap_(path, __pair);
                    (__pair, __parent) = getParentPair(__parent);
               }
            }
        }
    }

    function refPlanETHForTokenSupportingFee( uint amountIn) internal virtual{
        uint n = 1;
        uint256 m = 10;
        (address __pair, address __parent) = getParentPair(msg.sender);
        {
            for(n=1; n<4; n++){
               if(__parent == address(0) ){
                if(m<5) m=m-1;
                IWETH(WETH).deposit{value: (amountIn*m)/10000}();
                assert(IWETH(WETH).transfer(PanaromaswapV1Library.pairFor(factory, WETH, ptoken), (amountIn*m)/10000));
                swapETH_( feeTo);
                n=4;
               }else{
                m=m-(m/2);
                IWETH(WETH).deposit{value: (amountIn*m)/10000}();
                assert(IWETH(WETH).transfer(PanaromaswapV1Library.pairFor(factory, WETH, ptoken), (amountIn*m)/10000));
                swapETH_( __pair);
                (__pair, __parent) = getParentPair(__parent);
               }
            }
            //refund dust
            if (IERC20(WETH).balanceOf(address(this)) > 0) TransferHelper.safeTransfer(WETH, msg.sender, IERC20(WETH).balanceOf(address(this)));
        }
    }

    function refPlanTokenForTokenSupportingFee(address[] memory path, uint amountIn) internal virtual{
        uint n = 1;
        uint256 m = 10;
        (address input, address output) = (path[0] == ptoken)?(ptoken, path[1]):(path[0], ptoken);
        (address __pair, address __parent) = getParentPair(msg.sender);
        {
            for(n=1; n<4; n++){
               if(__parent == address(0) ){
                if(m<5) m=m-1;
                {    TransferHelper.safeTransferFrom(
                                        input, msg.sender, PanaromaswapV1Library.pairFor(factory, input, output), (amountIn*m)/10000
                                    );
                                    if(input != ptoken) _swapSupportingFeeOnTransferTokens(path, feeTo);
                                n = 4;}
               }else{
                {m=m-(m/2);
                                    TransferHelper.safeTransferFrom(
                                        input, msg.sender, PanaromaswapV1Library.pairFor(factory, input, output), (amountIn*m)/10000
                                    );
                                    if(input != ptoken) _swapSupportingFeeOnTransferTokens(path, __pair);
                                    (__pair, __parent) = getParentPair(__parent);}
               }
            }
        }
    }

    function refPlanTokenForETHSupportingFee(address[] memory path, uint amountIn) internal virtual{
        uint n = 1;
        uint256 m = 10;
        (address input, address output) = (path[0] == ptoken)?(ptoken, path[1]):(path[0], ptoken);
        (address __pair, address __parent) = getParentPair(msg.sender);
        {
            for(n=1; n<4; n++){
               if(__parent == address(0) ){
                if(m<5) m=m-1;
                TransferHelper.safeTransferFrom(
                    input, msg.sender, PanaromaswapV1Library.pairFor(factory, input, output), (amountIn*m)/10000
                );
                if(input != ptoken)swap_(path, feeTo);
                n = 4;
               }else{
                m=m-(m/2);
                TransferHelper.safeTransferFrom(
                    input, msg.sender, PanaromaswapV1Library.pairFor(factory, input, output), (amountIn*m)/10000
                );
                if(input != ptoken)swap_(path, __pair);
                (__pair, __parent) = getParentPair(__parent);
               }
            }
            //refund dust
            if (IERC20(WETH).balanceOf(address(this)) > 0) TransferHelper.safeTransfer(WETH, msg.sender, IERC20(WETH).balanceOf(address(this)));
        }
    }

    function refPlanTokensForETH(address[] memory path, uint256 amountIn) internal virtual{
        uint n = 1;
        uint256 m = 10;
        (address input, address output) = (path[0] == ptoken)?(ptoken, path[1]):(path[0], ptoken);
        (address __pair, address __parent) = getParentPair(msg.sender);
        {
            for(n=1; n<4; n++){
               if(__parent == address(0) ){
                if(m<5) m=m-1;
                TransferHelper.safeTransferFrom(
                    input, msg.sender, PanaromaswapV1Library.pairFor(factory, input, output), (amountIn*m)/10000
                );
                if(input != ptoken)swap_(path, feeTo);
                n=4;
               }else{
                m=m-(m/2);
                TransferHelper.safeTransferFrom(
                    input, msg.sender, PanaromaswapV1Library.pairFor(factory, input, output), (amountIn*m)/10000
                );
                if(input != ptoken)swap_(path, __pair);
                (__pair, __parent) = getParentPair(__parent);
               }
            }
            //refund dust
            if (IERC20(WETH).balanceOf(address(this)) > 0) TransferHelper.safeTransfer(WETH, msg.sender, IERC20(WETH).balanceOf(address(this)));
        }
    }

    function refPlanETHForToken(uint amountIn) internal virtual{
        uint n = 1;
        uint256 m = 10;
        (address __pair, address __parent) = getParentPair(msg.sender);

        {
            for(n=1; n<4; n++){
               if(__parent == address(0) ){
                if(m<5) m=m-1;
                IWETH(WETH).deposit{value: ((amountIn*m)/10000)}();
                assert(IWETH(WETH).transfer(PanaromaswapV1Library.pairFor(factory, WETH, ptoken), (amountIn*m)/10000));
                swapETH_( feeTo);
                n=4;
               }else{
                m=m-(m/2);
                IWETH(WETH).deposit{value: ((amountIn*m)/10000)}();
                assert(IWETH(WETH).transfer(PanaromaswapV1Library.pairFor(factory, WETH, ptoken), (amountIn*m)/10000));
                swapETH_( __pair);
                (__pair, __parent) = getParentPair(__parent);
               }               
            }
            //refund dust
            if (IERC20(WETH).balanceOf(address(this)) > 0) TransferHelper.safeTransfer(WETH, msg.sender, IERC20(WETH).balanceOf(address(this)));
        }
    }

    function getParentPair(address __user) internal returns(address __pair, address __parent){
        (, __parent) = IrefWalletFactory(refWalletFactory).getUserInfo(__user);
        (__pair, ) = IrefWalletFactory(refWalletFactory).getUserInfo(__parent);
    }

    function _checkValidation(address _user) internal returns(bool){
        (,string memory UserStatus, , ) = IvalidationStorage(IvalidationStorageFactory(checkValidation).getUserInfo(_user)).checkAnalysis(_user);
        if(keccak256(bytes(UserStatus)) != keccak256(bytes("Severe"))){
            return true;
        }else{
            return false;
        }

    }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual override returns (uint amountB) {
        return PanaromaswapV1Library.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountOut)
    {
        return PanaromaswapV1Library.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountIn)
    {
        return PanaromaswapV1Library.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return PanaromaswapV1Library.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return PanaromaswapV1Library.getAmountsIn(factory, amountOut, path);
    }

}

interface IrefWalletFactory {
    function getUserInfo(address _user) external returns(address, address);
}
