// TaskItem.swift
import Foundation

struct TaskItem: Codable, Identifiable {
    let id: Int
    let title: String
    let description: String?
    let owner_id: Int
}
