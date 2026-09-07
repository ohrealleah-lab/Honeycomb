package com.leah.honeycomb

class UndoStack<T>(private val capacity: Int = 100) {
    private val stack = mutableListOf<T>()

    fun push(state: T) {
        stack.add(state)
        if (stack.size > capacity) {
            stack.removeAt(0)
        }
    }

    fun pop(): T? {
        if (stack.isEmpty()) return null
        return stack.removeAt(stack.size - 1)
    }

    fun peek(): T? {
        return stack.lastOrNull()
    }

    fun clear() {
        stack.clear()
    }

    val canUndo: Boolean
        get() = stack.isNotEmpty()
        
    val size: Int
        get() = stack.size
}
