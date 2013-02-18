###
# Class to give lots of info about a Sturmian sequence
###
class SturmainSeq
    constructor: (@theta, @offset=0) ->
        if not (@theta instanceof ContinuedFraction)
            @theta = new ContinuedFraction(@theta)
    getDigits: (n) ->
        theta = @theta.value
        x = @offset
        ret = []
        for i in [0...n]
            ret.push Math.floor((i+1)*theta + x) - Math.floor(i*theta + x)
        return ret.join('')
    largestLevelBelowLength: (maxLen) ->
        # figure out how far we can go without overshooting maxLen
        maxIterations = 0
        for [p,q] in @theta.convergents
            if Math.abs(q) > maxLen
                break
            maxIterations += 1
        return maxIterations

    getLevels: (maxLen=30) ->
        levels = ['1','0']
        # figure out how far we can go without overshooting maxLen
        maxIterations = @largestLevelBelowLength(maxLen) - 2

        # ignore the first continuant since its alwasy 0 for numbers less than 1
        for a,i in @theta.continuants.slice(1)
            a = Math.abs(a)
            if i > maxIterations
                break
            # the first continued fraction digit needs to be treated specially
            if i is 0
                newLevel = Array(a).join(levels[i+1]) + levels[i]
            else
                newLevel = Array(a+1).join(levels[i+1]) + levels[i]
            levels.push newLevel
        return levels

    getFormattedDigits: (maxLen=30) ->
        # '\u200b' is a zero-width space for wrapping purposes.
        levels = ["<span level='0'>1</span>\u200b", "<span level='1'>0</span>\u200b"]

        maxIterations = @largestLevelBelowLength(maxLen) - 2

        # ignore the first continuant since its alwasy 0 for numbers less than 1
        for a,i in @theta.continuants.slice(1)
            a = Math.abs(a)
            if i > maxIterations
                break
            if i is 0
                newLevel = Array(a).join(levels[i+1]) + levels[i]
            else
                newLevel = Array(a+1).join(levels[i+1]) + levels[i]
            levels.push "<span level='#{i+2}'>#{newLevel}</span>"
        return levels[levels.length - 1]

$(document).ready ->
    #
    # Set up the tabs
    #
    $('#nav div').click (event) ->
        elm = $(event.currentTarget)
        $('#displayarea [page]').hide()
        $(elm.attr('href')).show()
        $('#nav div').removeClass('selected')
        elm.addClass('selected')
        switch elm.attr('href')
            when '#sequenceview'
                updateSeqView(new ContinuedFraction(ContinuedFraction.evaluateMath($('#decimal').val())))
            when '#fractionview'
                updateContinuedFraction(new ContinuedFraction(ContinuedFraction.evaluateMath($('#decimal').val())))
                
                


    window.seqView = new SeqView

    cf = ContinuedFraction.inputbox
        decimalInput: '#decimal'
        continuedFractionInput: '#continuedfraction'
        updateCallback: (frac) ->
            updateSeqView(frac)

            updateCircleView(frac)

            updateContinuedFraction(frac)
            return
    frac = cf.frac
    sturm = new SturmainSeq(frac)


    #
    # Handle the sequence view page
    #
    DIGITS = 500
    updateSeqView = (frac) ->
        seq = new SturmainSeq(frac)
        seqView.update(seq, DIGITS)
        # hide any levels that are not displayed
        maxLevel = seq.largestLevelBelowLength(DIGITS)
        for elm in $('#levelchooser li')
            level = parseInt(elm.getAttribute('level'), 10)
            if level < maxLevel
                $(elm).show()
            else
                $(elm).hide()

        MathJax.Hub.Queue(["Typeset", MathJax.Hub, $('#levelshower')[0]])

    seqView.createLevelsView(sturm, DIGITS)
    seqView.createLevelsList(sturm, DIGITS)

    $('#sequence').html seqView.prettySeq
    $('#levelshower').html seqView.levelsList
    seqView.highlightLevel()
    
    # callbacks for when we click to highlight different superblocks
    $('#levelchooser li').click (evt) ->
        elm = evt.currentTarget
        level = parseInt(elm.getAttribute('level'),10)
        seqView.highlightLevel(level)
        $('#levelchooser li').removeClass('selected')
        $(elm).addClass('selected')
    updateSeqView(new ContinuedFraction(ContinuedFraction.evaluateMath($('#decimal').val())))

    #
    # Handle the circle view
    #
    window.circle = new SVGCircle
    $('#circlecontainer').append circle.svg
    $('#iterate').click ->
        circle.drawNSteps(1)
    $('#reset').click ->
        circle.update(null,0,0)
    updateCircleView = (frac) ->
        circle.update(frac.value)

    #
    # Handle the Continued Fraction view
    #
    updateContinuedFraction = (frac) ->
        table = $("<table></table>")
        for [a,b],i in frac.convergents.slice(0,20)
            table.append("""<tr>
                <td>$\\displaystyle\\frac{p_{#{i}}}{q_{#{i}}} = 
                \\displaystyle\\frac{#{a}}{#{b}}$
                <span class="approx">$\\approx #{a/b}$</span>
                </td>
            </tr>""")
        $('#convergents .content').html table
        $('#prettyprinted .content').html """
            \\[#{frac.toLatex(10)}\\]
        """
        
        MathJax.Hub.Queue(["Typeset", MathJax.Hub, $('#continuants .content')[0]])
        return
    

class SeqView
    constructor: (@sturm) ->
    update: (@sturm, digits=100) ->
        oldPrettySeq = @prettySeq
        @createLevelsView(@sturm, digits)
        oldPrettySeq.replaceWith @prettySeq

        oldLevelsList = @levelsList
        @createLevelsList(@sturm, digits)
        oldLevelsList.replaceWith @levelsList
        
        @highlightLevel(@previousHighlightLevel) if @previousHighlightLevel?

    createLevelsView: (sturm=@sturm, digits=100) ->
        seq = sturm.getFormattedDigits(digits)
        @prettySeq = $(seq)
    createLevelsList: (sturm=@sturm, digits=100) ->
        levels = sturm.getLevels(digits)
        view = $("<ul></ul>")
        for s,i in levels
            view.append("<li level='#{i}'>${\\bf s}_{#{i}}$ = #{s}</li>")
        @levelsList = view

    highlightLevel: (level=1) ->
        @previousHighlightLevel = level
        # recursively highlights the sequence.
        # we need to do this because levels are nested in a
        # funny way.
        walk = (parent, level) ->
            if parseInt(parent.attr('level'), 10) == level
                parent.addClass('level1')
                return
            for elm in parent.children()
                elm = $(elm)
                l = parseInt(elm.attr('level'), 10)
                if l > level
                    walk(elm, level)
                if l == level
                    elm.addClass('level1')
                if l == level - 1
                    elm.addClass('level0')
        # makes sure nothing is highlighted atm.
        @prettySeq.find('.level1').removeClass('level1')
        @prettySeq.find('.level0').removeClass('level0')

        if @levelsList
            @levelsList.find('.level1').removeClass('level1')
            @levelsList.find('.level0').removeClass('level0')
            @levelsList.find("[level=#{level}]").addClass('level1')
            @levelsList.find("[level=#{level-1}]").addClass('level0')

        walk(@prettySeq, level)

class SVGCircle
    createElmNS = (name, attrs={}, parent) ->
        NAMESPACE = "http://www.w3.org/2000/svg"
        elm = document.createElementNS(NAMESPACE, name)
        # HACK: when we convert to a string, we'd like the namespace to
        # appear on root svg nodes, so force it to appear by prententing
        # it is an attribute
        if name is 'svg'
            elm.setAttribute('xmlns', NAMESPACE)

        for k,v of attrs
            elm.setAttribute(k,v)
        if parent?
            parent.appendChild(elm)
        return addEasyAttrs(elm)
    # allows you to get and set an elements attributes
    # via elm.attrs() or elm.attrs({foo:bar, baz:bang}).
    # This is added via expando property.
    addEasyAttrs = (elm) ->
        elm.attr = (attr) ->
            if not attr?
                ret = {}
                for attr in elm.attributes
                    ret[attr.name] = attr.value
                return ret
            if typeof attr is 'string'
                return elm.getAttribute(attr)
            for name,val of attr
                elm.setAttribute(name, val)
            return elm
        return elm

    #constructor: (@theta=0.38196601125, @offset=0) ->
    constructor: (@theta=1/(3+1/(2+1/7.54154354)), @offset=0) ->
        @unmoddedOffset = @offset
        @thetaCont = new ContinuedFraction(@theta)
        @numsteps = 0
        @tickLens = ([q, 15/Math.sqrt(i+1)] for [p,q],i in @thetaCont.convergents)

        
        @svg = createElmNS('svg')
        @svg.attr
            width: 400
            height: 400
        @width = 400
        @height = 400

        @defs = createElmNS('defs',{},@svg)
        @style = createElmNS('style', {type:'text/css'},@defs)
        @style.textContent = """
            .thetaback {
                    fill: rgba(45, 188, 255, 0.54);
            }
            .thetaline {
                    stroke: #06F;
            }
            .marker {
                    fill: #0014F8;
                    stroke: rgba(255, 255, 255, 0.72);
                    stroke-width: 2;
            }
            .seq {
                    font-family: sans-serif;
                    font-size: 20;
            }
            .thetatext {
                    font-family: serif;
                    font-size: 40;
            }"""


        @radius = 300/2
        @displayGroup = createElmNS('g', {transform: "translate(#{@width/2},#{@height/2})"}, @svg)
        
        @ticksList = []

        circle = createElmNS('circle', {r:@radius, fill:'none', stroke:'black'}, @displayGroup)
        #tick = @radialTick(0)
        #createElmNS('line', {x1:tick[0][0], y1:tick[0][1], x2:tick[1][0], y2:tick[1][1], stroke:'black'}, @displayGroup)
        #tick = @radialTick(@theta)
        #createElmNS('line', {x1:tick[0][0], y1:tick[0][1], x2:tick[1][0], y2:tick[1][1], stroke:'black'}, @displayGroup)
        start = @toCircleCoords(0)
        end = @toCircleCoords(@theta)
        flag = if @theta < .5 then 0 else 1     # the sweep flag for an svg arc
        @thetaHighlight = createElmNS('path', {d:"M#{start} A #{@radius} #{@radius} 0 #{flag} 0 #{end} L 0 0 Z", stroke:'none', fill:'lightblue', 'class': 'thetaback'}, @displayGroup)
        @thetaWedge = createElmNS('path', {d:"M#{start} A #{@radius} #{@radius} 0 #{flag} 0 #{end}", stroke:'blue', fill:'none', 'stroke-width': 3, 'class': 'thetaline'}, @displayGroup)
        labelPos = [-Math.sin(2*Math.PI*@theta/2) * 20, -Math.cos(2*Math.PI*@theta/2) * 20]
        label = createElmNS('text', {x: labelPos[0], y: labelPos[1]+5, 'font-size': 40, 'text-anchor': 'middle', 'class':'thetatext'}, @displayGroup)
        label.textContent = '\u03b8' #'θ'


        pos = @toCircleCoords(@offset)
        @offsetMarker = createElmNS('circle', {r:5, cx: "0", cy: "#{-@radius}", transform: "rotate(-#{@offset*360})", stroke:'none', fill:'black', 'class':'marker'}, @displayGroup)
        window.c = @offsetMarker

        @seq = createElmNS('text',{x:20,y:30, 'class': 'seq', 'font-size': 20},@svg)
        newDigit = if @offset < @theta then 1 else 0
        @newDigit(newDigit)
    update: (theta=@theta, @offset=0, numsteps) ->
        @theta = theta
        @thetaCont = new ContinuedFraction(@theta)
        numsteps = @numsteps if not numsteps?
        @numsteps = 0
        for elm in @ticksList
            $(elm).remove()
        
        start = @toCircleCoords(0)
        end = @toCircleCoords(@theta)
        flag = if @theta < .5 then 0 else 1     # the sweep flag for an svg arc
        @thetaHighlight.attr
            d: "M#{start} A #{@radius} #{@radius} 0 #{flag} 0 #{end} L 0 0 Z"
        @thetaWedge.attr
            d: "M#{start} A #{@radius} #{@radius} 0 #{flag} 0 #{end}"
        @drawNSteps(numsteps, {animate: false})


    toCircleCoords: (angle) ->
        x = -Math.sin(2*Math.PI*angle)
        y = Math.cos(2*Math.PI*angle)
        return [@radius*x,-@radius*y]   # in graphics the y-axis is pointed downward
        
    # given angle in [0,1), returns the start
    # and end coordinates of a tick pointed radially 
    # of length length
    radialTick: (angle, length=15) ->
        x = -Math.sin(2*Math.PI*angle)
        y = Math.cos(2*Math.PI*angle)

        return [[x*(@radius+length/2), -y*(@radius+length/2)],[x*(@radius-length/2), -y*(@radius-length/2)]]

    drawNSteps: (n=1, ops={animate: true}) ->
        @numsteps += n
        
        tickLen = 20
        for [q,l] in @tickLens
            if @numsteps <= q + 1
                tickLen = l
                break

        oldOffset = @offset
        path = ""
        for i in [0...n]
            @offset = (@offset + @theta) % 1
            @unmoddedOffset = @unmoddedOffset + @theta
            tick = @radialTick(@offset, tickLen)
            path += "M #{tick[0]} L #{tick[1]} "
        @ticksList.push createElmNS('path', {d:path, stroke:'black'}, @displayGroup)
        
        digits = (new SturmainSeq(@theta)).getDigits(@numsteps)
        if ops.animate
            @animComplete = =>
                @seq.textContent = digits
            @animateRotation(oldOffset, @offset)
        else
            @offsetMarker.attr
                transform: "rotate(#{-@offset*360})"
            @seq.textContent = digits
            

    drawNextStep: (ops={animate: true})->
        @numsteps += 1
        
        tickLen = 20
        for [q,l] in @tickLens
            if @numsteps <= q + 1
                tickLen = l
                break

        tick = @radialTick(@offset, tickLen)
        createElmNS('line', {x1:tick[0][0], y1:tick[0][1], x2:tick[1][0], y2:tick[1][1], stroke:'black'}, @displayGroup)

        @offset = (@offset + @theta) % 1
        @unmoddedOffset = @unmoddedOffset + @theta
        if ops.animate
            @animateRotation(@unmoddedOffset-@theta, @unmoddedOffset, 250, 30)
        else
            @offsetMarker.attr
                transform: "rotate(-#{@unmoddedOffset*360})"
            newDigit = if @offset < @theta then 1 else 0
            @newDigit(newDigit)
    animateRotation: (from=0, to=1, duration=1000, frames=60) ->
        easingFunc = (x) -> x*x
        # always take the shortest path around the circle, which sometimes means
        # we go backwards
        to = (1 + (to % 1)) % 1     # mod 1 and ensure we're positive
        from = (1 + (from % 1)) % 1
        forwardDist = Math.abs(to - from)
        backwardDist = 1 - forwardDist
        if forwardDist > backwardDist
            from  = to - backwardDist
        easing = (easingFunc(i/frames) for i in [0..frames])
        easing = (from + (to-from)*e for e in easing)

        delay = Math.floor(duration/frames)
        i = 0

        update = =>
            if i < frames
                @offsetMarker.attr
                    transform: "rotate(#{-easing[i]*360})"
                i += 1
                window.setTimeout(update, delay)
                return
            if i == frames
                @offsetMarker.attr
                    transform: "rotate(#{-to*360})"
                for _ in [0..10]
                    @animComplete?()

        window.setTimeout(update, 0)
        
    newDigit: (d) ->
        @seq.textContent = @seq.textContent + d
