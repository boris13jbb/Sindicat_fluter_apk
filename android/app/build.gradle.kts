import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
val allowDebugReleaseSigning =
    providers.gradleProperty("allowDebugReleaseSigning").orNull == "true" ||
        System.getenv("ALLOW_DEBUG_RELEASE_SIGNING")?.equals("true", ignoreCase = true) == true

if (hasReleaseSigning) {
    FileInputStream(keystorePropertiesFile).use(keystoreProperties::load)
}

fun requireSigningProperty(name: String): String =
    keystoreProperties.getProperty(name)?.takeIf { it.isNotBlank() }
        ?: throw GradleException(
            "Falta '$name' en android/key.properties. Usa android/key.properties.example como plantilla.",
        )

if (
    gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) } &&
    !hasReleaseSigning &&
    !allowDebugReleaseSigning
) {
    throw GradleException(
        "Build release bloqueado: configura android/key.properties con la firma productiva. " +
            "Para una compilación QA local explícita usa ALLOW_DEBUG_RELEASE_SIGNING=true.",
    )
}

android {
    namespace = "com.sindicato.votos.fluter_apk"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.skyrunner.sindicato"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = requireSigningProperty("keyAlias")
                keyPassword = requireSigningProperty("keyPassword")
                storeFile = file(requireSigningProperty("storeFile"))
                storePassword = requireSigningProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                when {
                    hasReleaseSigning -> signingConfigs.getByName("release")
                    allowDebugReleaseSigning -> signingConfigs.getByName("debug")
                    else -> null
                }
        }
    }
}

flutter {
    source = "../.."
}
