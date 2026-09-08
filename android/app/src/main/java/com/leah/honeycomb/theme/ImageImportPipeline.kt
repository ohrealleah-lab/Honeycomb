package com.leah.honeycomb.theme

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

// Shared by CustomBackgroundManager and CustomCardBackManager — open the picked image,
// reject it outright over the size cap (never downscale to fit), downsample to maxDim,
// and save it as a PNG under storageDir. Was previously copy-pasted between the two
// managers (and a third, deleted Face Card Art manager), differing only in maxDim.
object ImageImportPipeline {
    fun importAndDownscale(context: Context, uri: Uri, storageDir: File, maxDim: Int, maxBytes: Long = 25 * 1024 * 1024): Result<String> {
        var pfd: android.os.ParcelFileDescriptor? = null
        return try {
            pfd = context.contentResolver.openFileDescriptor(uri, "r")
                ?: return Result.failure(Exception("Cannot open file"))
            if (pfd.statSize > maxBytes) {
                return Result.failure(Exception("File exceeds ${maxBytes / (1024 * 1024)}MB limit"))
            }

            val boundsOptions = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFileDescriptor(pfd.fileDescriptor, null, boundsOptions)

            var sampleSize = 1
            while (boundsOptions.outWidth / sampleSize > maxDim || boundsOptions.outHeight / sampleSize > maxDim) {
                sampleSize *= 2
            }

            val decodeOptions = BitmapFactory.Options().apply { inSampleSize = sampleSize }
            val bitmap: Bitmap = BitmapFactory.decodeFileDescriptor(pfd.fileDescriptor, null, decodeOptions)
                ?: return Result.failure(Exception("Failed to decode image"))

            val fileName = "${UUID.randomUUID()}.png"
            FileOutputStream(File(storageDir, fileName)).use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            }

            Result.success(fileName)
        } catch (e: Exception) {
            Result.failure(e)
        } finally {
            pfd?.close()
        }
    }
}
