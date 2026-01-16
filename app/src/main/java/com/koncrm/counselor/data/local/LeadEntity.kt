package com.koncrm.counselor.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "leads")
data class LeadEntity(
    @PrimaryKey
    val id: Long,
    val studentName: String,
    val phoneNumber: String,
    val email: String?,
    val status: String,
    val universityId: Long?,
    val universityName: String?,
    val counselorId: Long?,
    val counselorName: String?,
    val branchId: Long?,
    val createdAt: Long,
    val updatedAt: Long,
    val lastSyncedAt: Long = System.currentTimeMillis()
)

@Entity(tableName = "pending_actions")
data class PendingActionEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val leadId: Long,
    val actionType: String, // "note", "status", "followup"
    val payload: String, // JSON payload
    val createdAt: Long = System.currentTimeMillis(),
    val retryCount: Int = 0
)
