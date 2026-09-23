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
// Certains plugins (flutter_native_splash 2.4.4) figent un compileSdk 31 dans
// leur propre build.gradle, ce que refuse la verification des metadonnees AAR
// des librairies AndroidX recentes. On releve donc le compileSdk des
// sous-projets restes en dessous de celui de l'app. Ce bloc doit rester avant
// `evaluationDependsOn(":app")`, qui evalue les projets et rendrait
// `afterEvaluate` trop tardif.
subprojects {
    afterEvaluate {
        val androidExtension = project.extensions.findByName("android") ?: return@afterEvaluate
        val getCompileSdk = androidExtension.javaClass.methods
            .firstOrNull { it.name == "getCompileSdk" && it.parameterCount == 0 }
        val setCompileSdk = androidExtension.javaClass.methods
            .firstOrNull { it.name == "setCompileSdk" && it.parameterCount == 1 }
            ?: return@afterEvaluate
        val current = getCompileSdk?.invoke(androidExtension) as? Int
        if (current == null || current < 36) {
            setCompileSdk.invoke(androidExtension, 36)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
