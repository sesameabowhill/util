import io.gatling.recorder.GatlingRecorder
import io.gatling.recorder.config.RecorderPropertiesBuilder

// Provided by the gatling maven archetype. used to launch the simulation recorder from the IDE.
object Recorder extends App {

	val props = new RecorderPropertiesBuilder
	props.simulationOutputFolder(IDEPathHelper.recorderOutputDirectory.toString)
	props.simulationPackage("com.sesamecom.loadtest")
	props.bodiesFolder(IDEPathHelper.bodiesDirectory.toString)

	GatlingRecorder.fromMap(props.build, Some(IDEPathHelper.recorderConfigFile))
}
