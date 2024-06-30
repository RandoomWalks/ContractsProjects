// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title DynamicArrayManager
 * @dev Simplified contract to manage a dynamic array of integers. This contract includes
 * functionalities to add, remove, and retrieve items from the array
 */
contract DynamicArrayManager {
    uint[] public items;

    event ItemAdded(uint item);
    event ItemRemoved(uint index);

    /**
     * @dev Adds a new item to the array.
     * @param _item The item to be added.
     */
    function addItem(uint _item) public {
        items.push(_item);
        emit ItemAdded(_item);
    }

    /**
     * @dev Removes an item at a specified index from the array.
     * @notice This function attempts to remove an item by shifting the last item
     * to the removed item's position
     */
    function removeItem(uint _index) public {
        require(_index < items.length, "Index out of bounds.");

        if (_index < items.length - 1) {
            items[_index] = items[items.length - 1];
        }
        items.pop();
        emit ItemRemoved(_index);
    }

    /**
     * @dev Retrieves an item by its index.
     * @param _index The index of the item to retrieve.
     * @return The item at the specified index.
     */
    function getItem(uint _index) public view returns (uint) {
        require(_index < items.length, "Index out of bounds.");
        return items[_index];
    }

    /**
     * @dev Returns the current size of the array.
     * @return The size of the items array.
     */
    function getSize() public view returns (uint) {
        return items.length;
    }

    /**
     * @dev Returns the entire array.
     * @return The items array.
     */
    function getAllItems() public view returns (uint[] memory) {
        return items;
    }
}
