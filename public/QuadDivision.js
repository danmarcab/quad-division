import {Elm} from '../src/Main.elm'

window.startQuadDivision = ({node, elmUIEmbedded = false}) => {
    const app = Elm.Main.init({
        node,
        flags: {
            elmUIEmbedded, viewport:
                {width: window.innerWidth, height: window.innerHeight}
        }
    });

    window.addEventListener("resize", function () {
        app.ports.windowResizes.send({width: window.innerWidth, height: window.innerHeight});
    });

    app.ports.downloadSvg.subscribe(svgId => {
        const svg = document.getElementById(svgId);
        const svgAsXML = (new XMLSerializer).serializeToString(svg);
        const dataURL = "data:image/svg+xml," + encodeURIComponent(svgAsXML);

        const dl = document.createElement("a");
        document.body.appendChild(dl); // This line makes it work in Firefox.
        dl.setAttribute("href", dataURL);
        dl.setAttribute("download", `${svgId}.svg`);
        dl.click();
    });
};
