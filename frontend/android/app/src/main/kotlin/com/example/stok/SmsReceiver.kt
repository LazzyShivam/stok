package com.example.stok

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            for (message in messages) {
                // SMS received — Flutter side handles via method channel if needed
                android.util.Log.d("SmsReceiver", "SMS from ${message.originatingAddress}: ${message.messageBody}")
            }
        }
    }
}
