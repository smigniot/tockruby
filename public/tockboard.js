function buildBoard(outercontainer) {
    var MU = 0
    for(var i=0; i<=15; i++) {
        MU += Math.cos(i*Math.PI/30);
    }

    function makeSVG(tag, attrs) {
        var el = document.createElementNS('http://www.w3.org/2000/svg', tag);
        for (var k in attrs) {
            el.setAttribute(k, attrs[k]);
        }
        return el;
    }

    function radiusFor(width, spacing) {
        return (width-spacing*(6+2*MU))/(4*MU+10);
    }

    function makeArc(x0,y0,radius,distance,container,alpha,color) {
        var x = x0, y = y0, i=0;
        for(i=0; i<16; i++) {
            makeCell(x,y,radius,container,i?i:20,
                    (i==0)?'tockbase':'tockplace',color);
            x += Math.cos(alpha)*distance;
            y -= Math.sin(alpha)*distance;
            alpha += Math.PI/30;
        }
        alpha -= Math.PI/30;
        alpha -= Math.PI/2;
        var x19 = 0;
        var y19 = 0;
        for(i=16; i<20; i++) {
            if(i!=19) {
                makeCell(x,y,radius,container,i,null,color);
            } else {
                x19 = x;
                y19 = y;
            }
            x += Math.cos(alpha)*distance;
            y -= Math.sin(alpha)*distance;
        }
        x -= 2*Math.cos(alpha)*distance;
        y += 2*Math.sin(alpha)*distance;
        alpha += Math.PI/2;
        for(i=19; i<=22; i++) {
            x -= Math.cos(alpha)*distance;
            y += Math.sin(alpha)*distance;
            makeCell(x,y,radius,container,i,'tocklane',color);
        }
        makeCell(x19,y19,radius,container,19,null,color);
    }

    var POSITIONS = ['West','North','East','South'];
    var COLORS = ['yellow','red','blue','green'];
    var CSSCOLORS = ['#FFDD00','red','blue','green'];

    function makeCell(x,y,radius,container,num,klass,color) {
        klass = klass || 'tockplace';
        var g = makeSVG('g', {'class':'tockcell'});
        var circle = makeSVG("circle", {
                'cx':x, 'cy':y, 'r':radius,
                'filter':'url(#dropshadow)',
                'class':klass });
        if('tockbase' == klass) {
            circle.setAttribute('fill',
                    CSSCOLORS[COLORS.indexOf(color)]);
        }
        g.appendChild(circle);
        var text = makeSVG("text", {
                'x':x, 'y':y,
                'class':klass });
        if('tocklane' == klass) {
            text.setAttribute('fill', CSSCOLORS[
                    (COLORS.indexOf(color)+1)%4
                    ]);
        }
        text.textContent = num;
        g.appendChild(text);
        container.appendChild(g);
	container.appendChild(document.createTextNode("\n"));
        //var dy = text.getBBox().height/2-4;
        //text.setAttribute("transform", 'translate(0,'+dy+')');
    }


    var WINDOW_MARGIN = 16;
    var SHADOW_MARGIN = 6;
    var W = (window.innerWidth || d.documentElement.clientWidth 
            || outercontainer.clientWidth)-WINDOW_MARGIN;
    var H = (window.innerHeight || d.documentElement.clientHeight
            || outercontainer.clientHeight)-WINDOW_MARGIN;
    var w = W-SHADOW_MARGIN;
    var h = H-SHADOW_MARGIN;
    var width = 1024;
    //console.log(width);
    var side = width+SHADOW_MARGIN;
    var container = makeSVG('svg', {
        'class':'tockboard',
        'viewBox':'0 0 '+side+' '+side,
        });
    outercontainer.appendChild(container);
    container.innerHTML = (
            '<defs>'+
            '<filter id="dropshadow" height="130%" width="130%">'+
            '<feGaussianBlur in="SourceAlpha" stdDeviation="2"/>'+
            '<feOffset dx="2" dy="2" result="offsetblur"/>'+
            '<feComponentTransfer>'+
            '<feFuncA type="linear" slope="0.3"></feFuncA>'+
            '</feComponentTransfer>      '+
            '<feMerge>'+
            '<feMergeNode/>'+
            '<feMergeNode in="SourceGraphic"></feMergeNode>'+
            '</feMerge>'+
            '</filter>'+
            '</defs>'
        );
    var spacing = 1;
    var radius = radiusFor(width, spacing);
    var distance = 2*radius+spacing;

    var x0 = spacing+radius,
        y0 = spacing+radius+MU*distance,
        D = 4*distance;
    makeArc(y0,2*y0+D-x0,radius,distance,container, Math.PI/2,'green');
    makeArc(x0,y0,radius,distance,container, 0,'yellow');
    makeArc(y0+D,x0,radius,distance,container, -Math.PI/2,'red');
    makeArc(2*y0+D-x0,y0+D,radius,distance,container, Math.PI,'blue');

    var a = document.body.appendChild(document.createElement("a"));
    a.textContent = "Source";
    a.setAttribute("download","svg.html");
    a.setAttribute("href","data:text/html;base64,"+btoa(container.parentNode.innerHTML));

    return container;
}

