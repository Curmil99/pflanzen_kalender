buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // AGP-Version kompatibel mit isar_flutter_libs 3.1.0
        classpath("com.android.tools.build:gradle:7.4.1")
        // Kotlin Plugin (falls dein Projekt Kotlin nutzt)
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.10")
    }
}

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
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
