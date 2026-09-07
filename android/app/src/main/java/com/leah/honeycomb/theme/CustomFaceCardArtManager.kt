package com.leah.honeycomb.theme

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import kotlinx.coroutines.CoroutineScope
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

class CustomFaceCardArtManager(
    private val context: Context,
    private val coroutineScope: CoroutineScope,
    private val themeManager: ThemeManager
) {
    private val storageDir: File
        get() {
            val dir = File(context.filesDir, "FaceArt")
            if (!dir.exists()) dir.mkdirs()
            return dir
        }

    fun deleteFaceArt(relativePath: String) {
        val file = File(storageDir, relativePath)
        if (file.exists()) file.delete()
        
        themeManager.clearFaceArtReferences(relativePath)
    }

    fun addFaceArt(uri: Uri): Result<String> {
        try {
            val pfd = context.contentResolver.openFileDescriptor(uri, "r") ?: return Result.failure(Exception("Cannot open file"))
            val sizeBytes = pfd.statSize
            if (sizeBytes > 25 * 1024 * 1024) {
                pfd.close()
                return Result.failure(Exception("File exceeds 25MB limit"))
            }
            
            val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFileDescriptor(pfd.fileDescriptor, null, options)
            
            var scale = 1
            val maxDim = 1200 // Max 1200px
            while (options.outWidth / scale > maxDim || options.outHeight / scale > maxDim) {
                scale *= 2
            }
            
            val decodeOptions = BitmapFactory.Options().apply { inSampleSize = scale }
            val bitmap = BitmapFactory.decodeFileDescriptor(pfd.fileDescriptor, null, decodeOptions)
            pfd.close()
            
            if (bitmap == null) return Result.failure(Exception("Failed to decode image"))

            val fileName = "${UUID.randomUUID()}.png"
            val file = File(storageDir, fileName)
            FileOutputStream(file).use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            }
            
            return Result.success(fileName)
        } catch (e: Exception) {
            return Result.failure(e)
        }
    }
}
