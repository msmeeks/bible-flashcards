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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
