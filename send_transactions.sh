#!/bin/bash

function echo_blue_bold {
    echo -e "\033[1;34m$1\033[0m"
}

PRIVATE_KEY_FILE="private_key.txt"

if [ -f "$PRIVATE_KEY_FILE" ]; then
    echo_blue_bold "Using stored private key from $PRIVATE_KEY_FILE"
    privateKeys=$(cat $PRIVATE_KEY_FILE)
else
    echo
    echo_blue_bold "Enter private key:"
    read -s privateKeys
    echo "$privateKeys" > $PRIVATE_KEY_FILE
    echo_blue_bold "Private key stored in $PRIVATE_KEY_FILE"
fi

echo
echo_blue_bold "Using RPC URL: https://testnet-rpc.superposition.so/"
providerURL="https://testnet-rpc.superposition.so/"
echo
echo_blue_bold "Contract address: 0xE934c31A0aEfB7D5840203b86FD11b26AE1A27b4"
contractAddress="0xE934c31A0aEfB7D5840203b86FD11b26AE1A27b4"
echo
echo_blue_bold "Transaction data (in hex): 0xa9059cbb000000000000000000000000a7eccdb9be08178f896c26b7bbd8c3d4e844d9ba00000000000000000000000000000000000000000000003635c9adc5dea00000"
transactionData="0xa9059cbb000000000000000000000000a7eccdb9be08178f896c26b7bbd8c3d4e844d9ba00000000000000000000000000000000000000000000003635c9adc5dea00000"
echo
echo_blue_bold "Gas limit: 92000"
gasLimit="92000"
echo
echo_blue_bold "Gas price (in gwei): 0.02"
gasPrice="0.02"
echo

addresses_file="addresses.txt"
processed_addresses_file="processed_addresses.txt"

if [ ! -f "$addresses_file" ]; then
    echo "Error: addresses.txt file not found."
    exit 1
fi

if ! npm list ethers@5.5.4 >/dev/null 2>&1; then
  echo_blue_bold "Installing ethers..."
  npm install ethers@5.5.4
  echo
else
  echo_blue_bold "Ethers is already installed."
fi
echo

temp_node_file=$(mktemp /tmp/node_script.XXXXXX.js)

cat << EOF > $temp_node_file
const fs = require("fs");
const ethers = require("ethers");

const providerURL = "${providerURL}";
const provider = new ethers.providers.JsonRpcProvider(providerURL);

const privateKeys = "${privateKeys}";

const contractAddress = "${contractAddress}";

const transactionData = "${transactionData}";

const gasLimit = ethers.BigNumber.from(${gasLimit});

const gasPrice = ethers.utils.parseUnits("${gasPrice}", 'gwei');

async function sendTransaction(wallet, toAddress) {
    const tx = {
        to: toAddress,
        value: 0,
        gasLimit: gasLimit,
        gasPrice: gasPrice,
        data: transactionData,
    };

    try {
        const transactionResponse = await wallet.sendTransaction(tx);
        console.log("\033[1;35mTx Hash:\033[0m", transactionResponse.hash);
        const receipt = await transactionResponse.wait();
        console.log("");
        return true;
    } catch (error) {
        console.error("Error sending transaction to", toAddress, ":", error);
        return false;
    }
}

async function main() {
    const wallet = new ethers.Wallet(privateKeys, provider);

    const addresses = fs.readFileSync("${addresses_file}", 'utf-8').split("\\n").filter(Boolean);
    const processedAddresses = fs.existsSync("${processed_addresses_file}") ? fs.readFileSync("${processed_addresses_file}", 'utf-8').split("\\n").filter(Boolean) : [];

    for (let i = 0; i < addresses.length; i++) {
        const toAddress = addresses[i];

        if (processedAddresses.includes(toAddress)) {
            console.log("Skipping address", toAddress, "- Already processed.");
            continue;
        }

        console.log("Sending transaction to", toAddress);
        const success = await sendTransaction(wallet, toAddress);

        if (success) {
            fs.appendFileSync("${processed_addresses_file}", toAddress + "\\n");
            console.log("Transaction sent successfully to", toAddress);
        } else {
            console.log("Failed to send transaction to", toAddress);
        }
    }
}

main().catch(console.error);
EOF

NODE_PATH=$(npm root -g):$(pwd)/node_modules node $temp_node_file

rm $temp_node_file
echo
echo_blue_bold "Transactions sent as per addresses in addresses.txt. Check processed_addresses.txt for details."
