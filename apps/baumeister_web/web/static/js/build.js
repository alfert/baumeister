// Setting up the build channel from Phoenix

let Build = {

  init(socket, buildname){
    if (!buildname) { return }
    let build_channel = socket.channel("build:lobby", {module: "Build"})
    build_channel.join()
      .receive("ok", resp => { console.log("Joined successfully", resp) })
      .receive("error", resp => { console.log("Unable to join", resp) })
    let msgContainer = document.getElementById("msg-container")
    build_channel.on("build_event", (event) => console.log("Got build event " + event))
  }
}
export default Build;
