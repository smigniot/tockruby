function _(s) { return document.querySelector(s) }
function __(s) {return [].slice.call(document.querySelectorAll("g.tockcell"))}
function boot() {
    // 1. Parse the game
	var game = JSON.parse(document.querySelector(
		"#gamejson").textContent);
	var color = document.location.pathname
		.replace(/\/play/,"").split(/\//).pop();

    // 2. Hide all cards
    var c = _("#allcards");
    for(var i=1; i<=13; i++) {
        "hearts,diamonds,spades,clubs".split(/,/g).forEach(function(j) {
            cardfor({color:j,value:i}).style.display = "none";
        })
    }
    c.style.display = "block";

    // 3. Update
    startcontinuousupdate(color);
	//update(game,color);
}
var REFCOUNT = 0;
var MYCOLOR = null;
var FREQ = 3000;
function startcontinuousupdate(color) {
    MYCOLOR = color;
    continuousupdate();
}
function continuousupdate() {
    d3.text("../refcount", function(err,res) {
        //console.log("RC", err,res);
        var refcount = +res;
        if(refcount > REFCOUNT) {
            d3.text("state.json", function(err,res) {
                console.log("UP", err,res);
                game = JSON.parse(res);
                REFCOUNT = refcount;
                update(game, MYCOLOR);
                setTimeout(continuousupdate, FREQ);
            });
        } else {
            setTimeout(continuousupdate, FREQ);
        }
    });
}
function cardfor(card) {
	var c = {
		hearts:"H",
		diamonds:"D",
		spades:"S",
		clubs:"C",
	}[card.color];
	var v = {
		1:"A",
		2:"2",
		3:"3",
		4:"4",
		5:"5",
		6:"6",
		7:"7",
		8:"8",
		9:"9",
		10:"10",
	}[card.value];
	var node = null;
	try {
		// id = "4C"
		node = document.getElementById(v+c);
	} catch(err) {
	}
	var magicid = {
		"11C":"g4130",
		"12C":"g4183",
		"13C":"g4230",
		"11H":"g3966",
		"12H":"g4021",
		"13H":"g4069",
		"11S":"g3874",
		"12S":"g3952",
		"13S":"g3963",
		"11D":"g3829",
		"12D":"g3839",
		"13D":"g3850",
	}[card.value+c];
	try {
		// id = "4C"
		node = node || document.getElementById(magicid);
	} catch(err) {
	}

	return node || _("#BACK_BLUE1");
}
var POSITIONS = ['West','North','East','South'];
var COLORS = ['yellow','red','blue','green'];
function update(game,color) {
	console.log(">> update",game,color);

	// 1. Wait other players
	var reg = (game.phase == "registering");
	_("#registering").style.display = reg?"block":"none";
	var exc = (game.phase == "exchanging");
	var ply = (game.phase == "playing");

	// 2. Display cards
	if(exc || ply) {
		var svg = _("svg.tockboard");
		var hand = game[color].hand;
		hand.forEach(function(c,i) {
			var cf = cardfor(c);
            //var g = svg.appendChild(cf.cloneNode(true));
            var g = svg.appendChild(cf.parentNode.removeChild(cf));
            g.style.display = "block";
            g.setAttribute("transform","");
            var bb = g.getBBox();
            g.setAttribute("transform", [
                "translate(",650+i*60," 835) ",
                "scale(0.6) ",
                "translate(",-bb.x," ",-bb.y,")"
                ].join(""));
            g.addEventListener("click", function(e) {
                cardClicked(game,color,c) });
		});
	}

    // 3. Display pawns
    POSITIONS.forEach(function(cardinalpos,i) {
        var p = game[cardinalpos.toLowerCase()] || {pawns:[]};
        var deltas = {
            yellow:{base:24,dx:0,dy:-1},
            green: {base:0,dx:-1,dy:0},
            red:   {base:48,dx:1,dy:0},
            blue:  {base:72,dx:0,dy:1},
        };
        var pdl = 2;
        p.pawns.forEach(function(pawn,j) {
            var pos = pawn.position;
            var ele = _("#pawn"+COLORS[i]+j);
            //if((i==2)&&(j==3)) pos = 70;
            if(pos == -1) {
                var d = deltas[COLORS[i]];
                var cell = __("g.tockcell")[d.base];
                var bb = cell.getBBox();
                var x = bb.x+(pdl+j)*d.dx*42;
                var y = bb.y+(pdl+j)*d.dy*42;
                var cx = x+bb.width/2;
                var cy = y+bb.height/2;
                ele.setAttribute("cx",cx);
                ele.setAttribute("cy",cy);
                //console.log("OUT",cell,d);
            } else {
                var cell = __("g.tockcell")[pos];
                var bb = cell.getBBox();
                var cx = bb.x+bb.width/2;
                var cy = bb.y+bb.height/2;
                ele.setAttribute("cx",cx);
                ele.setAttribute("cy",cy);
            }
            //console.log("PAWN",i,j,!!ele);
        });
    });

    d3.select("#DEBUG").text(
        "Elements: "+d3.selectAll("*").size()
        +"\nRefcount: "+REFCOUNT
    );
	console.log("<< update",game,color);
}
function cardClicked(game, color, card) {
	var exc = (game.phase == "exchanging");
	var ply = (game.phase == "playing");

    if(exc) {
        d3.request("play")
            .header("Content-Type", "application/json")
            .post(JSON.stringify({type:"exchange",card:card}),
                function(err, dat){
                    console.log("got response", err,dat);
                });
    } else {
        alert("TODO: play "+JSON.stringify(card));
    }
}


