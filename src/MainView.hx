package ;

import haxe.ui.containers.VBox;
import haxe.ui.events.MouseEvent;

@:build(haxe.ui.ComponentBuilder.build("assets/main-view.xml"))
class MainView extends VBox {
    public function new() {
        super();

        var nodes = [];
        for (i in 0...5) {
            nodes.push(graph.newNode());
        }
        
        graph.linkNodes(nodes[0], nodes[1], true);
    }
}