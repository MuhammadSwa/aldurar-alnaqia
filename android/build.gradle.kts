allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
    // Force plugins (e.g. :jni from pdfrx) to reuse the installed NDK
    // instead of downloading their own pinned version.
    if (project.state.executed) {
        val androidExt = project.extensions.findByName("android")
        if (androidExt is com.android.build.gradle.BaseExtension) {
            androidExt.ndkVersion = "27.1.12297006"
        }
    } else {
        project.afterEvaluate {
            val androidExt = project.extensions.findByName("android")
            if (androidExt is com.android.build.gradle.BaseExtension) {
                androidExt.ndkVersion = "27.1.12297006"
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

