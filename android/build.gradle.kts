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

// isar_flutter_libs 3.x ships without a `namespace` in its build.gradle,
// which is required by AGP 8+. Inject it from the manifest at config time.
subprojects {
    afterEvaluate {
        if (project.plugins.hasPlugin("com.android.library")) {
            val android = project.extensions.findByName("android")
                ?: return@afterEvaluate
            val getNs = runCatching {
                android.javaClass.getMethod("getNamespace").invoke(android)
            }.getOrNull()
            if (getNs == null) {
                val manifest = project.file("src/main/AndroidManifest.xml")
                if (manifest.exists()) {
                    val pkg = manifest.readText()
                        .substringAfter("package=\"", "")
                        .substringBefore("\"", "")
                    if (pkg.isNotEmpty()) {
                        runCatching {
                            android.javaClass.getMethod("setNamespace", String::class.java)
                                .invoke(android, pkg)
                        }
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
