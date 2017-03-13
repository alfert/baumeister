// Setting up the build channel from Phoenix

let Build = {

  init(socket, build_element){
    if (!build_element) { return }
    let buildId  = build_element.getAttribute("build-id")
    let build_channel = socket.channel("build:" + buildId, {module: "Build"})
    build_channel.join()
      .receive("ok", resp => { console.log("Joined successfully", resp) })
      .receive("error", resp => { console.log("Unable to join", resp) })
    let msgContainer = document.getElementById("msg-container")
    build_channel.on("build_event", (event) => this.renderLogMessage(msgContainer, event))
     // console.log("Got build event " + event))
  },

  renderLogMessage(msgContainer, event) {
    let template = document.createElement("div")
    template.innerHTML = `
    <p><b>${event.role}:</b><i>${event.action}</i> &mdash; ${event.step}</p>
    `
    msgContainer.appendChild(template)
    msgContainer.scrollTop = msgContainer.scrollHeight
    // [Log] receive:  build:lobby build_event  –
    // {step: "%Baumeister.Observer.Coordinate{observer: Baumeist…opPlugin,
    //   url: \"www.northpole.com\", version: nil}",
    //   role: "observer",
    //   action: "execute"}
  }
}
export default Build
