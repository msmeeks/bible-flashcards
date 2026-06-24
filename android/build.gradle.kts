allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// flutter_timezone's build.gradle sets kotlinOptions.jvmTarget = 1.8 but never
// sets Android compileOptions, so AGP defaults javac to 11 — mismatched
// against its own Kotlin target. Align javac to 1.8 to match.
subprojects {
    if (project.name == "flutter_timezone") {
        afterEvaluate {
            extensions.findByType<com.android.build.gradle.LibraryExtension>()?.apply {
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_1_8
                    targetCompatibility = JavaVersion.VERSION_1_8
                }
            }
        }
    }
}

// file_picker skips applying org.jetbrains.kotlin.android itself on AGP 9+,
// expecting AGP's built-in Kotlin support to compile its Kotlin sources —
// but this Flutter version's plugin loader doesn't enable that path, so its
// Kotlin classes never compile. Apply the plugin explicitly as a workaround.
subprojects {
    if (project.name == "file_picker") {
        apply(plugin = "org.jetbrains.kotlin.android")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
