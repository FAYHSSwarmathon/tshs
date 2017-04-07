;; Terry Sanford High School
;; High School Division Swarmathon
;;
;; John M. Harris, Jr. <johnmh@openblox.org>

;; We load parkingLot.jpg, so we need this lib
extensions[bitmap]

;; Defaults. I edit in GNU Emacs, so I need these values listed
;; so I can duplicate them in NetLogo once I want to test my code.

;; singleRocks 50
;; clusterRocks 30
;; largeClusterRocks 5
;; numberOfRobots 6

breed [robots robot]

;; States:
;; 0 Looking for clusters
;; 1 Bringing back rock
;; 2 Going to known rock clusters

robots-own[
	state

	phase

	;;Target X/Y coords
	targX
	targY

	initHeading

	searchAngle

	isSearcher?
]

patches-own [
	baseColor

	storedCoords
]

;; Setup func
to setup
	ca
	cp
	reset-ticks
   
	bitmap:copy-to-pcolors bitmap:import "parkingLot.jpg" true

	make-robots
	make-rocks
	make-base
end

;; Searchers do *nothing but* searching

to make-robots
	create-robots numberOfRobots[
		set size 5
		set shape "robot"
		set color red
		
		set state 0

		set phase 0

		set targX 0
		set targY 0

		set initHeading random 360
		set heading initHeading

		set searchAngle one-of [ 1 5 13 ]
	]
end

to make-rocks
	ask patches[
		set baseColor pcolor
		set storedCoords []
	]

	make-random
	make-clusters
	make-large-clusters
end


to make-random
	let targetPatches singleRocks
	while [targetPatches > 0][
		ask one-of patches[
			if pcolor != yellow[
				set pcolor yellow
				set targetPatches targetPatches - 1
			]
		]
	]
end

to make-clusters
	let targetClusters clusterRocks
	while [targetClusters > 0][
		ask one-of patches[
			if pcolor != yellow and [pcolor] of neighbors4 != yellow[
				set pcolor yellow
				ask neighbors4[
					set pcolor yellow
				]
				set targetClusters targetClusters - 1
			]
		]
	]
end

to make-large-clusters
	let targetLargeClusters largeClusterRocks
	while [targetLArgeClusters > 0][
		ask one-of patches[
			if pcolor != yellow and [pcolor] of patches in-radius 3 != yellow[
				set pcolor yellow
				ask patches in-radius 3[
					set pcolor yellow
				]
				set targetLargeClusters targetLargeClusters - 1
			]
		]
	]
end

to make-base
	ask patches[
		if distancexy 0 0 = 0[
			set pcolor green
			set storedCoords []
		]
	]
end

to robot-control
	ask robots[
		do-robot-control
	]

	tick
end

;; Begin "virtual radio" code
;; I would love to have implemented this as just a send/recv system
;; Do it uART style, one bit on the wire at a time! Extra realism.
;; Issue with that is wasted ticks.
to-report robot-coord-eq [c1 c2]
	report ((first c1) = (first c2)) and ((last c1) = (last c2))
end

to-report get-base
	report patch-at 0 0
end

to robot-process-list
	let base get-base

	ask base[
		ifelse not empty? storedCoords[
			let loc first storedCoords

			ask myself[
				set targX first loc
				set targY last loc
			]

			set storedCoords but-first storedCoords

			ask myself[
				set state 2
			]
		][
			ask myself[
				set state 1
				robot-return-to-base
			]
		]
	]
end

to give-base-coord [x y]
	let base get-base

	ask base[
		let location (list x y)
		set storedCoords remove-duplicates (fput location storedCoords)
	]
end

to broadcast-found-rocks
	ask neighbors[
		if pcolor = yellow[
			give-base-coord pxcor pycor
		]
	]
end

to look-for-rocks
	ask neighbors[
		if pcolor = yellow[
			set pcolor baseColor

			ask myself[
				set state 1
				set shape "robot with rock"
				robot-return-to-base
			]
		]
	]
	broadcast-found-rocks
end

to robot-look-for-clusters
	if phase = 0[
		;; If on the border, grab the closest rock and go to base
		ifelse not can-move? 1[
			look-for-rocks
			if not (shape = "robot with rock")[
				robot-process-list
			]
		][
			broadcast-found-rocks
			fd 1
		]
	]
end

to robot-return-to-base
	ifelse (pxcor = 0 and pycor = 0)[
		ifelse phase = 0[
			;; Does it have a rock?
			ifelse shape = "robot with rock"[
				set shape "robot"
			][
				look-for-rocks
			]

			
			let base get-base

			ask base[
				;; They're at the base, let's get them back out there.
				ifelse (not empty? storedCoords) [
					;; We know where some rocks are! Let's go get them.
					ask myself[
						robot-process-list
					]
				][
					ask myself[
						set state 0

						set initHeading initHeading + searchAngle
						set heading initHeading

						robot-look-for-clusters
					]
				]
			]
			
			][
				if shape = "robot with rock"[
					set shape "robot"
				]
			]
	][
		if shape = "robot"[
			look-for-rocks
		]
		facexy 0 0
		fd 1
	]
end

to robot-go-to-target
	ifelse (pxcor = targX and pycor = targY)[
		set shape "robot with rock"

		ask patch-here[
			set pcolor baseColor
		]

		broadcast-found-rocks

		set state 1
		robot-return-to-base
	][
		facexy targX targY
		fd 1
	]
end

to do-robot-control
	if state = 0 [robot-look-for-clusters]
	if state = 1 [robot-return-to-base]
	if state = 2 [robot-go-to-target]
end