package com.koncrm.counselor.util

import com.koncrm.counselor.data.local.LeadPhone

object PhoneMatcher {
    fun keys(phone: String?): List<String> {
        if (phone.isNullOrBlank()) return emptyList()
        val digits = phone.filter { it.isDigit() }
        if (digits.length < 7) return emptyList()

        val keys = LinkedHashSet<String>()
        keys.add(digits)
        if (digits.length > 10) {
            keys.add(digits.takeLast(10))
        }
        return keys.toList()
    }
}

class LeadPhoneIndex(private val index: Map<String, Long>) {
    fun findLeadId(phone: String?): Long? {
        for (key in PhoneMatcher.keys(phone)) {
            val leadId = index[key]
            if (leadId != null) {
                return leadId
            }
        }
        return null
    }

    fun isEmpty(): Boolean = index.isEmpty()

    companion object {
        fun from(leads: List<LeadPhone>): LeadPhoneIndex {
            val map = mutableMapOf<String, Long>()
            for (lead in leads) {
                for (key in PhoneMatcher.keys(lead.phoneNumber)) {
                    map.putIfAbsent(key, lead.id)
                }
            }
            return LeadPhoneIndex(map)
        }
    }
}
