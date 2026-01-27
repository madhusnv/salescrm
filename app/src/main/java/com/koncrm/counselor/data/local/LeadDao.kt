package com.koncrm.counselor.data.local

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface LeadDao {
    @Query("SELECT * FROM leads ORDER BY updatedAt DESC")
    fun getAllLeads(): Flow<List<LeadEntity>>

    @Query("SELECT * FROM leads WHERE id = :id")
    suspend fun getLeadById(id: Long): LeadEntity?

    @Query("SELECT * FROM leads WHERE phoneNumber LIKE :phone")
    suspend fun findByPhone(phone: String): LeadEntity?

    @Query("SELECT * FROM leads WHERE studentName LIKE '%' || :query || '%' OR phoneNumber LIKE '%' || :query || '%' OR email LIKE '%' || :query || '%'")
    fun searchLeads(query: String): Flow<List<LeadEntity>>

    @Query("SELECT * FROM leads WHERE status = :status ORDER BY updatedAt DESC")
    fun getLeadsByStatus(status: String): Flow<List<LeadEntity>>

    @Query("SELECT id, phoneNumber FROM leads")
    suspend fun getLeadPhones(): List<LeadPhone>

    @Query("SELECT COUNT(*) FROM leads")
    suspend fun getLeadCount(): Int

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertLead(lead: LeadEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertLeads(leads: List<LeadEntity>)

    @Transaction
    suspend fun replaceLeads(leads: List<LeadEntity>) {
        clearAll()
        if (leads.isNotEmpty()) {
            insertLeads(leads)
        }
    }

    @Update
    suspend fun updateLead(lead: LeadEntity)

    @Delete
    suspend fun deleteLead(lead: LeadEntity)

    @Query("DELETE FROM leads")
    suspend fun clearAll()
}

@Dao
interface PendingActionDao {
    @Query("SELECT * FROM pending_actions ORDER BY createdAt ASC")
    suspend fun getAllPending(): List<PendingActionEntity>

    @Query("SELECT * FROM pending_actions WHERE leadId = :leadId")
    suspend fun getPendingForLead(leadId: Long): List<PendingActionEntity>

    @Insert
    suspend fun insert(action: PendingActionEntity)

    @Delete
    suspend fun delete(action: PendingActionEntity)

    @Query("DELETE FROM pending_actions WHERE id = :id")
    suspend fun deleteById(id: Long)

    @Query("UPDATE pending_actions SET retryCount = retryCount + 1 WHERE id = :id")
    suspend fun incrementRetry(id: Long)

    @Query("SELECT COUNT(*) FROM pending_actions")
    fun getPendingCount(): Flow<Int>
}

data class LeadPhone(
    val id: Long,
    val phoneNumber: String
)
