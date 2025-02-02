// Constants
const CONTRACT_ADDRESS = "0x03F3C923eE87b89572849CACDb3e619292F618a7";
const SEPOLIA_CHAIN_ID = 11155111; // Sepolia network

// Global variables
let provider, signer, contract;
let txHistoryList = [];

// Notification helper
function notify(message, type = "info") {
  const notifications = document.getElementById("notifications");
  const alertDiv = document.createElement("div");
  alertDiv.className = `alert alert-${type}`;
  alertDiv.innerText = message;
  notifications.appendChild(alertDiv);
  setTimeout(() => alertDiv.remove(), 5000);
}

// Transaction history update
function updateTxHistory() {
  const history = document.getElementById("txHistory");
  history.innerHTML = "";
  txHistoryList.forEach(tx => {
    const li = document.createElement("li");
    li.className = "list-group-item";
    li.innerHTML = `<strong>${tx.action}</strong> - <a href="https://sepolia.etherscan.io/tx/${tx.hash}" target="_blank">${tx.hash.substring(0, 20)}...</a>`;
    history.appendChild(li);
  });
}

// Button loading state toggle
function setLoading(btn, isLoading, originalText) {
  if (isLoading) {
    btn.classList.add("loading");
    btn.disabled = true;
    btn.innerText = "Loading...";
  } else {
    btn.classList.remove("loading");
    btn.disabled = false;
    btn.innerText = originalText;
  }
}

// Initialize provider, signer, and contract; check network
async function init() {
  if (!window.ethereum) {
    notify("Please install MetaMask", "danger");
    return;
  }
  provider = new ethers.providers.Web3Provider(window.ethereum);
  await provider.send("eth_requestAccounts", []);
  signer = provider.getSigner();
  const network = await provider.getNetwork();
  if (network.chainId !== SEPOLIA_CHAIN_ID) {
    document.getElementById("networkStatus").innerText = "Please switch your network to Sepolia.";
    notify("Wrong network. Switch to Sepolia.", "warning");
    return;
  } else {
    document.getElementById("networkStatus").innerText = "Connected to Sepolia network.";
  }
  // Use the ABI loaded from contractABI.js
  contract = new ethers.Contract(CONTRACT_ADDRESS, contractABI, signer);
  setupContractEvents();
}

// Contract event listeners
function setupContractEvents() {
  contract.on("TokenCreated", (tokenId, name, description, value, owner, event) => {
    notify(`Token Created: ${name} (ID: ${tokenId})`, "success");
    txHistoryList.push({ action: "TokenCreated", hash: event.transactionHash });
    updateTxHistory();
  });
  contract.on("TokenActivated", (tokenId, tokenizer, owner, event) => {
    notify(`Token ${tokenId} Activated`, "success");
    txHistoryList.push({ action: "TokenActivated", hash: event.transactionHash });
    updateTxHistory();
  });
  // Additional event listeners can be added as needed.
}

// Event: Wallet connection
document.getElementById("connectWallet").addEventListener("click", init);

// Listen for network/account changes
if (window.ethereum) {
  window.ethereum.on("chainChanged", () => window.location.reload());
  window.ethereum.on("accountsChanged", () => window.location.reload());
}

// Create Token form
document.getElementById("createTokenForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  const btn = document.getElementById("createTokenBtn");
  const originalText = "Create Token";
  setLoading(btn, true, originalText);
  
  const name = document.getElementById("tokenName").value.trim();
  const description = document.getElementById("tokenDesc").value.trim();
  const value = parseInt(document.getElementById("tokenValue").value);
  const validity = parseInt(document.getElementById("tokenValidity").value);
  
  if (!name || !description || value <= 0 || validity <= 0) {
    notify("Please provide valid inputs for token creation.", "danger");
    setLoading(btn, false, originalText);
    return;
  }
  
  try {
    const tx = await contract.createToken(name, description, value, validity);
    notify("Token creation transaction sent.", "info");
    txHistoryList.push({ action: "createToken", hash: tx.hash });
    updateTxHistory();
    await tx.wait();
    notify("Token created successfully.", "success");
  } catch (err) {
    console.error(err);
    notify("Error creating token.", "danger");
  }
  setLoading(btn, false, originalText);
});

// Purchase Token form
document.getElementById("purchaseTokenForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  const btn = document.getElementById("purchaseTokenBtn");
  const originalText = "Purchase Token";
  setLoading(btn, true, originalText);
  
  const tokenId = document.getElementById("purchaseTokenId").value;
  if (tokenId === "") {
    notify("Please provide a valid Token ID.", "danger");
    setLoading(btn, false, originalText);
    return;
  }
  
  try {
    const price = await contract.tokenSellingPrice(tokenId);
    const tx = await contract.purchaseToken(tokenId, { value: price });
    notify("Purchase transaction sent.", "info");
    txHistoryList.push({ action: "purchaseToken", hash: tx.hash });
    updateTxHistory();
    await tx.wait();
    notify("Token purchased successfully.", "success");
  } catch (err) {
    console.error(err);
    notify("Error purchasing token.", "danger");
  }
  setLoading(btn, false, originalText);
});

// Set Token Price form
document.getElementById("setTokenPriceForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  const btn = document.getElementById("setTokenPriceBtn");
  const originalText = "Set Price";
  setLoading(btn, true, originalText);
  
  const tokenId = document.getElementById("priceTokenId").value;
  const newPrice = document.getElementById("newPrice").value;
  if (tokenId === "" || newPrice <= 0) {
    notify("Please provide valid Token ID and Price.", "danger");
    setLoading(btn, false, originalText);
    return;
  }
  
  try {
    const tx = await contract.setTokenSellingPrice(tokenId, newPrice);
    notify("Set price transaction sent.", "info");
    txHistoryList.push({ action: "setTokenPrice", hash: tx.hash });
    updateTxHistory();
    await tx.wait();
    notify("Price set successfully.", "success");
  } catch (err) {
    console.error(err);
    notify("Error setting price.", "danger");
  }
  setLoading(btn, false, originalText);
});

// Activate Token form
document.getElementById("activateTokenForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  const btn = document.getElementById("activateTokenBtn");
  const originalText = "Activate Token";
  setLoading(btn, true, originalText);
  
  const tokenId = document.getElementById("activateTokenId").value;
  if (tokenId === "") {
    notify("Please provide a valid Token ID.", "danger");
    setLoading(btn, false, originalText);
    return;
  }
  
  try {
    const tx = await contract.activateToken(tokenId);
    notify("Activation transaction sent.", "info");
    txHistoryList.push({ action: "activateToken", hash: tx.hash });
    updateTxHistory();
    await tx.wait();
    notify("Token activated successfully.", "success");
  } catch (err) {
    console.error(err);
    notify("Error activating token.", "danger");
  }
  setLoading(btn, false, originalText);
});

// Redemption Request form
document.getElementById("redemptionRequestForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  const btn = document.getElementById("redemptionRequestBtn");
  const originalText = "Request Redemption";
  setLoading(btn, true, originalText);
  
  const tokenId = document.getElementById("redeemTokenId").value;
  if (tokenId === "") {
    notify("Please provide a valid Token ID.", "danger");
    setLoading(btn, false, originalText);
    return;
  }
  
  try {
    const tx = await contract.redemptionRequest(tokenId);
    notify("Redemption request transaction sent.", "info");
    txHistoryList.push({ action: "redemptionRequest", hash: tx.hash });
    updateTxHistory();
    await tx.wait();
    notify("Redemption requested successfully.", "success");
  } catch (err) {
    console.error(err);
    notify("Error requesting redemption.", "danger");
  }
  setLoading(btn, false, originalText);
});

// Get Token Details form
document.getElementById("getTokenDetailsForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  const tokenId = document.getElementById("queryTokenId").value;
  if (tokenId === "") {
    notify("Please provide a valid Token ID.", "danger");
    return;
  }
  try {
    const tokenInfo = await contract.tokens(tokenId);
    const details = `
      <strong>Name:</strong> ${tokenInfo.name} <br>
      <strong>Description:</strong> ${tokenInfo.description} <br>
      <strong>Value:</strong> ${tokenInfo.initialValue} wei <br>
      <strong>State:</strong> ${tokenInfo.state} <br>
      <strong>Owner:</strong> ${tokenInfo.owner}
    `;
    document.getElementById("tokenDetails").innerHTML = details;
  } catch (err) {
    console.error(err);
    notify("Error fetching token details.", "danger");
  }
});
