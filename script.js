const { useState, useEffect } = React;

function App() {
  // Current active tab: vendor, trader, or warehousetokenizator
  const [currentTab, setCurrentTab] = useState("vendor");
  // Modal states
  const [modalVisible, setModalVisible] = useState(false);
  const [modalFunction, setModalFunction] = useState(null);
  const [modalValues, setModalValues] = useState({});
  const [modalErrors, setModalErrors] = useState({});
  // Notifications and events list
  const [notifications, setNotifications] = useState([]);
  const [events, setEvents] = useState([]);
  // Ethers.js objects
  const [provider, setProvider] = useState(null);
  const [signer, setSigner] = useState(null);
  const [contract, setContract] = useState(null);

  // Mapping of role to functions (and their parameters)
  // Updated mapping to include all external/public (non-view) functions.
  const roleFunctions = {
    vendor: [
      {
        name: "vendorRegistration",
        params: [
          { name: "_name", type: "string" },
          { name: "_email", type: "string" }
        ],
        payable: false
      },
      {
        name: "createToken",
        params: [
          { name: "_name", type: "string" },
          { name: "_description", type: "string" },
          { name: "_value", type: "uint256" },
          { name: "_timeValidity", type: "uint256" }
        ],
        payable: false
      },
      {
        name: "WTselection",
        params: [
          { name: "_tokenId", type: "uint256" },
          { name: "_messageHash", type: "bytes32" },
          { name: "_signature", type: "bytes" },
          { name: "_WTaddress", type: "address" },
          // “value” here lets the user send Ether if required.
          { name: "value", type: "ether" }
        ],
        payable: true
      },
      {
        name: "abortRequest",
        params: [{ name: "_tokenId", type: "uint256" }],
        payable: false
      },
      {
        name: "setNegativeFeedbackByOriginator",
        params: [{ name: "_tokenId", type: "uint256" }],
        payable: false
      },
      {
        name: "setTokenSellingPrice",
        params: [
          { name: "_tokenId", type: "uint256" },
          { name: "_sellingPrice", type: "uint256" }
        ],
        payable: false
      }
    ],
    trader: [
      {
        name: "purchaseToken",
        params: [
          { name: "_tokenId", type: "uint256" },
          { name: "value", type: "ether" }
        ],
        payable: true
      },
      {
        name: "redemptionRequest",
        params: [{ name: "_tokenId", type: "uint256" }],
        payable: false
      },
      {
        name: "setNegativeFeedbackByOwner",
        params: [{ name: "_tokenId", type: "uint256" }],
        payable: false
      }
    ],
    warehousetokenizator: [
      {
        name: "warehouseTokenizatorRegistration",
        params: [
          { name: "_name", type: "string" },
          { name: "_email", type: "string" },
          { name: "_latlon", type: "string" }
        ],
        payable: false
      },
      {
        name: "activateToken",
        params: [{ name: "_tokenId", type: "uint256" }],
        payable: false
      },
      {
        name: "burnToken",
        params: [
          { name: "_tokenId", type: "uint256" },
          { name: "_messageHash", type: "bytes32" },
          { name: "_signature", type: "bytes" }
        ],
        payable: false
      }
    ]
  };

  // Validation function for input values.
  const validateInput = (type, value) => {
    if (type === "uint256") {
      if (!/^\d+$/.test(value)) {
        return "Must be a positive integer.";
      }
    } else if (type === "ether") {
      // Should be a positive number (could include decimals)
      if (isNaN(value) || Number(value) < 0) {
        return "Must be a positive number.";
      }
    } else if (type === "address") {
      if (!/^0x[a-fA-F0-9]{40}$/.test(value)) {
        return "Invalid Ethereum address.";
      }
    } else if (type === "bytes32") {
      if (!/^0x[a-fA-F0-9]{64}$/.test(value)) {
        return "Must be a 32-byte hex string (0x followed by 64 hex digits).";
      }
    } else if (type === "bytes") {
      if (!/^0x([a-fA-F0-9]{2})+$/.test(value)) {
        return "Must be a hex string starting with 0x (even number of hex digits).";
      }
    } else if (type === "string") {
      if (value.trim() === "") {
        return "Cannot be empty.";
      }
    }
    return ""; // No error
  };

  // When an input field changes in the modal, update its value and check validity.
  const handleModalChange = (e, paramName, paramType) => {
    const val = e.target.value;
    // Validate the new value.
    const error = validateInput(paramType, val);
    setModalValues((prev) => ({ ...prev, [paramName]: val }));
    setModalErrors((prev) => ({ ...prev, [paramName]: error }));
  };

  // Determine if the modal form is valid (i.e. no errors and all required fields are filled).
  const isModalFormValid = () => {
    if (!modalFunction) return false;
    for (const param of modalFunction.params) {
      // Check if value exists.
      if (!modalValues[param.name]) {
        return false;
      }
      // Check if any error exists.
      if (modalErrors[param.name]) {
        return false;
      }
    }
    return true;
  };

  // Initialize connection to Ethereum and the smart contract.
  useEffect(() => {
    if (window.ethereum) {
      const prov = new ethers.providers.Web3Provider(window.ethereum);
      setProvider(prov);
      prov
        .send("eth_requestAccounts", [])
        .then(() => {
          const sign = prov.getSigner();
          setSigner(sign);
          // Your contract is deployed at this address on Sepolia:
          const contractAddress = "0x03F3C923eE87b89572849CACDb3e619292F618a7";
          // contractABI is assumed to be available from contractABI.js
          const instance = new ethers.Contract(contractAddress, contractABI, sign);
          setContract(instance);
          setupEventListeners(instance);
          addNotification("Connected to Ethereum network.");
        })
        .catch((err) => {
          addNotification("Connection error: " + err.message);
        });
    } else {
      addNotification("Please install MetaMask.");
    }
  }, []);

  // Subscribe to selected contract events.
  const setupEventListeners = (contractInstance) => {
    // Example: Listen for a few events.
    contractInstance.on("TokenCreated", (...args) => {
      addEvent("TokenCreated", args);
    });
    contractInstance.on("TokenActivated", (...args) => {
      addEvent("TokenActivated", args);
    });
    contractInstance.on("TokenBurned", (...args) => {
      addEvent("TokenBurned", args);
    });
    // Add further event subscriptions as needed.
  };

  // Add a notification message to be displayed.
  const addNotification = (message) => {
    setNotifications((prev) => [...prev, message]);
  };

  // Add an event to the events list.
  const addEvent = (eventName, args) => {
    // The last argument is the event object; we simply list the other arguments.
    const eventData = {
      eventName,
      args: args.slice(0, args.length - 1).map((a) => a.toString())
    };
    setEvents((prev) => [eventData, ...prev]);
  };

  // Open the modal for a function call.
  const openFunctionModal = (func) => {
    setModalFunction(func);
    setModalValues({});
    setModalErrors({});
    setModalVisible(true);
  };

  // Submit a transaction to call the selected contract function.
  const submitFunction = async () => {
    if (!contract) {
      addNotification("Contract not loaded.");
      return;
    }
    const funcName = modalFunction.name;
    let params = [];
    // Collect and cast parameters.
    for (const param of modalFunction.params) {
      if (param.name === "value") continue; // will handle payable value separately.
      let val = modalValues[param.name];
      if (val === undefined) {
        addNotification("Missing parameter: " + param.name);
        return;
      }
      // For numeric parameters, convert to BigNumber.
      if (param.type === "uint256") {
        val = ethers.BigNumber.from(val);
      }
      params.push(val);
    }
    try {
      let tx;
      if (modalFunction.payable) {
        let value = ethers.utils.parseEther(modalValues["value"] || "0");
        tx = await contract[funcName](...params, { value });
      } else {
        tx = await contract[funcName](...params);
      }
      addNotification(`${funcName} transaction sent. Tx hash: ${tx.hash}`);
      await tx.wait();
      addNotification(`${funcName} transaction confirmed.`);
    } catch (err) {
      addNotification(`${funcName} error: ${err.message}`);
    }
    setModalVisible(false);
  };

  return (
    <div className="container mt-3">
      <h1>Physical Asset Tokenization Interface</h1>
      {/* Tabs for roles */}
      <ul className="nav nav-tabs">
        {Object.keys(roleFunctions).map((role) => (
          <li className="nav-item" key={role}>
            <a
              className={`nav-link ${currentTab === role ? "active" : ""}`}
              href="#"
              onClick={() => setCurrentTab(role)}
            >
              {role.charAt(0).toUpperCase() + role.slice(1)}
            </a>
          </li>
        ))}
      </ul>
      <div className="tab-content mt-3">
        {roleFunctions[currentTab].map((func, index) => (
          <div key={index} className="mb-2">
            <button className="btn btn-primary" onClick={() => openFunctionModal(func)}>
              {func.name}
            </button>
          </div>
        ))}
      </div>

      {/* Central Modal for function input */}
      {modalVisible && modalFunction && (
        <div className="modal show" style={{ display: "block" }} tabIndex="-1">
          <div className="modal-dialog">
            <div className="modal-content">
              <div className="modal-header">
                <h5 className="modal-title">{modalFunction.name}</h5>
                <button type="button" className="close" onClick={() => setModalVisible(false)}>
                  <span>&times;</span>
                </button>
              </div>
              <div className="modal-body">
                {modalFunction.params.map((param, idx) => (
                  <div className="form-group" key={idx}>
                    <label>
                      {param.name} <small>({param.type})</small>
                    </label>
                    <input
                      type="text"
                      className={`form-control ${modalErrors[param.name] ? "is-invalid" : ""}`}
                      onChange={(e) => handleModalChange(e, param.name, param.type)}
                      placeholder={`Enter ${param.name}`}
                    />
                    {modalErrors[param.name] && (
                      <div className="invalid-feedback">{modalErrors[param.name]}</div>
                    )}
                  </div>
                ))}
              </div>
              <div className="modal-footer">
                <button className="btn btn-secondary" onClick={() => setModalVisible(false)}>
                  Cancel
                </button>
                <button
                  className="btn btn-primary"
                  onClick={submitFunction}
                  disabled={!isModalFormValid()}
                >
                  Submit
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Events display area */}
      <div className="mt-4">
        <h4>Events</h4>
        <div className="events-area border p-2" style={{ maxHeight: "200px", overflowY: "scroll" }}>
          {events.map((event, idx) => (
            <div key={idx}>
              <strong>{event.eventName}:</strong> {event.args.join(", ")}
            </div>
          ))}
        </div>
      </div>

      {/* Notifications area at the bottom */}
      <div className="mt-4">
        <h4>Notifications</h4>
        <div className="notifications-area border p-2">
          {notifications.map((note, idx) => (
            <div key={idx}>{note}</div>
          ))}
        </div>
      </div>
    </div>
  );
}

ReactDOM.render(<App />, document.getElementById("root"));
