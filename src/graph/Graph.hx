package graph;

import haxe.ds.Option;
import haxe.ui.events.MouseEvent;
import haxe.ui.util.Color;
import haxe.ui.graphics.ComponentGraphics;
import haxe.ui.core.Component;

using graph.Graph.ClickBoundsImpl;

enum ClickBounds {
    Rectangle(p0: Point, p1: Point, id: UInt);
    Circle(p: Point, radius: Float, id: UInt);
    Handle(p: Point, radius: Float, id: UInt, subID: UInt);
}

class ClickBoundsImpl {
    public static function overlaps(region: ClickBounds, event: MouseEvent): Bool {
        final mouseX = event.localX;
        final mouseY = event.localY;
        final mouseP = new Point(mouseX, mouseY);
        switch (region) {
            case Rectangle(p0, p1, _):
                return mouseX >= p0.x && mouseY >= p0.y && mouseX < p1.x && mouseY < p1.y;
            case Circle(p, radius, _):
                return p.dist(mouseP) <= radius;
            case Handle(p, radius, _, _):
                return p.dist(mouseP) <= radius;
        }
    }

    public static function xdiff(region: ClickBounds, event: MouseEvent): Float {
        final mouseX = event.localX;
        switch (region) {
            case Rectangle(p0, _, _):
                return p0.x - mouseX;
            case Circle(p, _, _):
                return p.x - mouseX;
            case Handle(p, _, _, _):
                return p.x - mouseX;
        }
    }

    public static function ydiff(region: ClickBounds, event: MouseEvent): Float {
        final mouseY = event.localY;
        switch (region) {
            case Rectangle(p0, _, _):
                return p0.y - mouseY;
            case Circle(p, _, _):
                return p.y - mouseY;
            case Handle(p, _, _, _):
                return p.y - mouseY;
        }
    }

    public static function id(region: ClickBounds): UInt {
        switch (region) {
            case Rectangle(_, _, id):
                return id;
            case Circle(_, _, id):
                return id;
            case Handle(_, _, id, _):
                return id;
        }
    }

    public static function subID(region: ClickBounds): Null<UInt> {
        switch (region) {
            case Rectangle(_, _, _):
                return null;
            case Circle(_, _, _):
                return null;
            case Handle(_, _, _, subID):
                return subID;
        }
    }
}

class _Point {
    public function new(x: Float, y: Float) {
        _x = x;
        _y = y;
    }

    private var _x: Float;
    private var _y: Float;

    public var x(get, set): Float;
    public var y(get, set): Float;

    private function get_x(): Float {
        return _x;
    }

    private function set_x(x: Float): Float {
        _x = x;
        return _x;
    }

    private function get_y(): Float {
        return _y;
    }

    private function set_y(y: Float): Float {
        _y = y;
        return _y;
    }
}

@:forward
abstract Point(_Point) from _Point to _Point {
    public function new(x: Float, y: Float) {
        this = new _Point(x, y);
    }

    public function dist(rhs: Point): Float {
        final x = rhs.x - this.x;
        final y = rhs.y - this.y;
        return Math.sqrt(x * x + y * y);
    }

    public function len(): Float {
        return dist(new Point(0, 0));
    }

    public function add_r_theta(r: Float, theta: Float): Point {
        return new Point(this.x + r * Math.cos(theta), this.y + r * Math.sin(theta));
    }

    public function angle(): Float {
        return Math.atan2(this.y, this.x);
    }

    @:op(A + B)
    public function add(rhs: Point): Point {
        return new Point(this.x + rhs.x, this.y + rhs.y);
    }

    @:op(A - B)
    public function subtract(rhs: Point): Point {
        return new Point(this.x - rhs.x, this.y - rhs.y);
    }

    @:op(A * B)
    public function multiply(rhs: Float): Point {
        return new Point(this.x * rhs, this.y * rhs);
    }

    @:op(A / B)
    public function divide(rhs: Float): Point {
        return new Point(this.x / rhs, this.y / rhs);
    }
}

@:allow(graph.Graph)
class Handle {
    private function new(id: UInt, xy: Point) {
        _id = id;
        _xy = xy;
    }

    private final _id: UInt;
    private var _xy: Point;
}

typedef Link = {
    var id: UInt;
    var wide: Bool;
    var handle0: Handle;
    var handle1: Handle;
}

@:allow(graph.Graph)
class Node {
    private function new(id: UInt, g: Graph) {
        _id = id;
        _xy = new Point(0, 0);
        _g = g;
    }

    private static var count: UInt = 0;

    private final _id: UInt;
    private var _to: Array<Link> = [];
    private var _from: Array<UInt> = [];

    private var _xy: Point;

    private final _g: Graph;

    public function lineTo(other: UInt, wide: Bool = false) {
        final rhs = _g.getNodeByID(other);
        final diff = rhs._xy - this._xy;
        final handle_dist = diff / 3;

        final handle0 = new Handle(count, this._xy + handle_dist);
        count++;
        final handle1 = new Handle(count, handle0._xy + handle_dist);
        count++;

        _to.push({
            id: other,
            wide: wide,
            handle0: handle0,
            handle1: handle1,
        });

        rhs._from.push(_id);
    }

    private function move(xy: Point, ?subID: UInt, both: Bool = true, angle: Bool = true) {
        if (subID == null) {
            for (to in _to) {
                if (angle) {
                    final rhs = _g.getNodeByID(to.id);
                    final scale = xy.dist(rhs._xy) / _xy.dist(rhs._xy);

                    final _angle = (rhs._xy - xy).angle() - (rhs._xy - _xy).angle();

                    final handle0_diff = to.handle0._xy - _xy;
                    final handle1_diff = to.handle1._xy - rhs._xy;
                    to.handle0._xy = xy.add_r_theta(handle0_diff.len() * if (both) { 1; } else { 1; }, handle0_diff.angle() + _angle);
                    if (both) {
                        to.handle1._xy = rhs._xy.add_r_theta(handle1_diff.len() * 1, handle1_diff.angle() + _angle);
                    }
                } else {
                    final diff = xy - _xy;

                    to.handle0._xy += diff;
                    if (both) {
                        to.handle1._xy += diff;
                    }
                }
            }

            for (from in _from) {
                final rhs = _g.getNodeByID(from);
                for (to in rhs._to.filter(function(l): Bool { return l.id == _id; })) {
                    if (angle) {
                        final scale = xy.dist(rhs._xy) / _xy.dist(rhs._xy);
                        final _angle = (rhs._xy - xy).angle() - (rhs._xy - _xy).angle();

                        final handle0_diff = to.handle0._xy - rhs._xy;
                        final handle1_diff = to.handle1._xy - _xy;
                        if (both) {
                            to.handle0._xy = rhs._xy.add_r_theta(handle0_diff.len() * 1, handle0_diff.angle() + _angle);
                        }
                        to.handle1._xy = xy.add_r_theta(handle1_diff.len() * if (both) { 1; } else { 1; }, handle1_diff.angle() + _angle);
                    } else {
                        final diff = xy - _xy;

                        if (both) {
                            to.handle0._xy += diff;
                        }
                        to.handle1._xy += diff;
                    }
                }
            }


            _xy = xy;
        } else {
            for (to in _to) {
                for (handle in [to.handle0, to.handle1]) {
                    if (handle._id == subID) {
                        handle._xy = xy;
                        return;
                    }
                }
            }
        }
    }
}

@:allow(graph.Graph)
class Graph extends Component {
    public var componentGraphics: ComponentGraphics;

    public function new() {
        super();

        componentGraphics = new ComponentGraphics(this);
    }

    private override function validateComponentLayout(): Bool {
        final b = super.validateComponentLayout();
        if (width <= 0 || height <= 0) {
            return b;
        }
        componentGraphics.resize(width, height);
        return b;
    }

    public override function cloneComponent(): Graph {
        @:privateAccess c.componentGraphics._drawCommands = this.componentGraphics._drawCommands.copy();
        @:privateAccess c.componentGraphics.replayDrawCommands();
        return c;
    }

    private override function onReady() {
        super.onReady();

        final scale = 0.5;

        final maxDim = Math.max(width, height);
        final radius = maxDim / 2;
        final xscale = width / maxDim * scale;
        final yscale = height / maxDim * scale;

        final xcentre = width / 2;
        final ycentre = height / 2;

        final radEach = Math.PI * 2 / _nodes.length;

        trace(xcentre, ycentre);

        for (index => node in _nodes) {
            final rad = index * radEach;

            final xcentre_this = xcentre + radius * xscale * Math.sin(rad);
            final ycentre_this = ycentre + radius * yscale * Math.cos(rad);

            node.move(new Point(xcentre_this, ycentre_this));
        }

        for (link in _links) {
            addLink(link.from, link.to, link.wide);
        }

        _links = null;

        frame();
    }

    private function arrow(from: UInt, link: Link, offset: Float = 0) {
        final TAU = Math.PI * 2;
        final xy0 = getNodeByID(from)._xy;
        final xy1 = getNodeByID(link.id)._xy;

        final diff = xy1 - link.handle1._xy;

        final angle = Math.atan2(diff.y, diff.x) + TAU / 2;
        final line0angle = angle + TAU / 8;
        final line1angle = angle - TAU / 8;

        final lineLength = 50;

        final line0 = xy1.add_r_theta(lineLength, line0angle);
        final line1 = xy1.add_r_theta(lineLength, line1angle);

        final _offset = new Point(0, 0).add_r_theta(offset, angle);
        final end = xy1 + _offset;
        final line0end = line0 + _offset;
        final line1end = line1 + _offset;

        componentGraphics.moveTo(end.x, end.y);
        componentGraphics.lineTo(line0end.x, line0end.y);

        componentGraphics.moveTo(end.x, end.y);
        componentGraphics.lineTo(line1end.x, line1end.y);


        componentGraphics.strokeStyle(Color.fromString("black"), if (link.wide) { 5; } else { 1; });

        componentGraphics.fillStyle(null);
        componentGraphics.moveTo(xy0.x, xy0.y);
        componentGraphics.cubicCurveTo(link.handle0._xy.x, link.handle0._xy.y, link.handle1._xy.x, link.handle1._xy.y, end.x, end.y);

        componentGraphics.strokeStyle(Color.fromString("black"), 1);
        componentGraphics.moveTo(xy0.x, xy0.y);
        componentGraphics.lineTo(link.handle0._xy.x, link.handle0._xy.y);
        componentGraphics.moveTo(xy1.x, xy1.y);
        componentGraphics.lineTo(link.handle1._xy.x, link.handle1._xy.y);

        componentGraphics.strokeStyle(Color.fromString("black"), 5);
        componentGraphics.fillStyle(Color.fromString("white"));

        componentGraphics.circle(link.handle0._xy.x, link.handle0._xy.y, 10);
        componentGraphics.circle(link.handle1._xy.x, link.handle1._xy.y, 10);
        clickRegions.push(Handle(link.handle0._xy, 10, from, link.handle0._id));
        clickRegions.push(Handle(link.handle1._xy, 10, from, link.handle1._id));
    }

    private var clickRegions: Array<ClickBounds> = [];
    private var clickX: Float;
    private var clickY: Float;
    private var clickID: Option<UInt> = None;
    private var clickSubID: Null<UInt> = null;
    private var clickBoth: Bool = true;
    private var clickAngle: Bool = true;

    public function frame() {
        if (_isDisposed) {
            return;
        }

        if (width != null && height != null) {
            componentGraphics.clear();
            clickRegions = [];

            for (node in _nodes) {
                for (link in node._to) {
                    final to = getNodeByID(link.id);
                    final from = node;
                    final wide = link.wide;

                    componentGraphics.strokeStyle(Color.fromString("black"), if (wide) { 5; } else { 1; });
                    arrow(from._id, link, 20);
                }
            }

            componentGraphics.strokeStyle(Color.fromString("black"), 5);
            componentGraphics.fillStyle(Color.fromString("white"));
            for (node in _nodes) {
                componentGraphics.circle(node._xy.x, node._xy.y, 20);
                clickRegions.push(Circle(node._xy, 20, node._id));
            }

            clickRegions.reverse();
        }
    }

    @:bind(this, MouseEvent.MOUSE_DOWN)
    private function onMouseDown(event: MouseEvent) {
        if (event == null) {
            return;
        }

        for (region in clickRegions) {
            if (region.overlaps(event)) {
                clickX = region.xdiff(event);
                clickY = region.ydiff(event);
                clickID = Some(region.id());
                clickSubID = region.subID();
                clickBoth = true;
                clickAngle = true;
                break;
            }
        }
    }

    @:bind(this, MouseEvent.RIGHT_MOUSE_DOWN)
    private function onRightMouseDown(event: MouseEvent) {
        if (event == null) {
            return;
        }

        for (region in clickRegions) {
            if (region.overlaps(event)) {
                clickX = region.xdiff(event);
                clickY = region.ydiff(event);
                clickID = Some(region.id());
                clickSubID = region.subID();
                clickBoth = false;
                clickAngle = false;
                break;
            }
        }
    }

    @:bind(this, MouseEvent.MIDDLE_MOUSE_DOWN)
    private function onMiddleMouseDown(event: MouseEvent) {
        if (event == null) {
            return;
        }

        for (region in clickRegions) {
            if (region.overlaps(event)) {
                clickX = region.xdiff(event);
                clickY = region.ydiff(event);
                clickID = Some(region.id());
                clickSubID = region.subID();
                clickBoth = false;
                clickAngle = true;
                break;
            }
        }
    }

    @:bind(this, MouseEvent.MOUSE_MOVE)
    private function onMouseMove(event: MouseEvent) {
        if (event == null) {
            return;
        }
        
        switch (clickID) {
            case Some(id):
                getNodeByID(id).move(new Point(event.localX + clickX, event.localY + clickY), clickSubID, clickBoth, clickAngle);
            case None:
                return;
        }

        frame();
    }

    @:bind(this, MouseEvent.MOUSE_UP)
    @:bind(this, MouseEvent.RIGHT_MOUSE_UP)
    @:bind(this, MouseEvent.MIDDLE_MOUSE_UP)
    private function onMouseUp(event: MouseEvent) {
        if (event == null) {
            return;
        }
        
        clickID = None;
        clickSubID = null;
    }

    private static var count: UInt = 0;

    private var _nodes: Array<Node> = [];

    private function getNodeByID(id: UInt): Node {
        return _nodes.filter(function(f: Node): Bool { return f._id == id; })[0];
    }

    public function newNode(): UInt {
        final n = new Node(count, this);
        final id = n._id;
        _nodes.push(n);
        count++;
        return id;
    }

    private var _links: Array<{var from: UInt; var to: UInt; var wide: Bool;}> = [];

    private function addLink(from: UInt, to: UInt, wide: Bool) {
        getNodeByID(from).lineTo(to, wide);
    }

    public function linkNodes(from: UInt, to: UInt, wide: Bool = false) {
        if (_links == null) {
            addLink(from, to, wide);
        } else {
            _links.push({from: from, to: to, wide: wide});
        }
    }
}