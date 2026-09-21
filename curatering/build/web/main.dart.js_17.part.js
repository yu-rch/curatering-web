((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,D={aLN:function aLN(){}},B,E
J=c[1]
A=c[0]
C=c[2]
D=a.updateHolder(c[14],D)
B=c[34]
E=c[35]
D.aLN.prototype={
EM(d){return this.azK(d)},
azK(d){var x=0,w=A.l(y.i),v,u,t,s,r,q
var $async$EM=A.m(function(e,f){if(e===1)return A.i(f,w)
for(;;)switch(x){case 0:x=3
return A.d(A.et(A.bx("https://curatering.up.railway.app/api/online-inquiries",0,null),C.a6.cp(d,null),null,E.kK).cA(C.fo),$async$EM)
case 3:q=f
if(q.b<200||q.b>=300){u="Failed to submit online inquiry ("+q.b+")"
try{s=q
t=C.a6.bp(A.cj(A.ci(s.e)).b7(s.w),null)
if(y.l.b(t)&&t.h(0,"message")!=null)u=J.u(t.h(0,"message"))}catch(p){}throw A.p(A.li(u,q.b))}s=q
if(C.e.l(A.cj(A.ci(s.e)).b7(s.w)).length===0){v=C.hU
x=1
break}s=q
t=C.a6.bp(A.cj(A.ci(s.e)).b7(s.w),null)
v=y.l.b(t)?A.av(t,y.g,y.b):C.hU
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$EM,w)},
a5u(d,e,f){return this.blU(d,e,f)},
blU(d,e,f){var x=0,w=A.l(y.i),v
var $async$a5u=A.m(function(g,h){if(g===1)return A.i(h,w)
for(;;)switch(x){case 0:v=$.bG().dV("/api/public/events/theme-design/yolo-sam-infer",A.N(["imageBase64",d,"confidenceThreshold",0.25,"maxDetections",f,"maskFormat",e],y.g,y.b)).cA(B.h5)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a5u,w)},
MB(d,e,f){return this.aF2(d,e,f)},
aF2(d,e,f){var x=0,w=A.l(y.i),v
var $async$MB=A.m(function(g,h){if(g===1)return A.i(h,w)
for(;;)switch(x){case 0:v=$.bG().dV("/api/public/events/theme-design/swap-colors",A.N(["imageBase64",e,"masks",f,"edits",d],y.g,y.b)).cA(B.h5)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$MB,w)},
WR(d,e,f,g,h,i,j,k){return this.ayt(d,e,f,g,h,i,j,k)},
ayt(d,e,f,g,h,i,j,k){var x=0,w=A.l(y.i),v
var $async$WR=A.m(function(l,m){if(l===1)return A.i(m,w)
for(;;)switch(x){case 0:v=$.bG().dV("/api/public/events/theme-design/theme-search",A.N(["eventTitle",e,"eventType",f,"formalityLevel",g,"prompt",j,"baseImageUrl",d,"tags",k,"page",h,"perPage",i],y.g,y.b)).cA(B.h5)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$WR,w)},
a4M(d){return this.bjF(d)},
bjF(d){var x=0,w=A.l(y.i),v
var $async$a4M=A.m(function(e,f){if(e===1)return A.i(f,w)
for(;;)switch(x){case 0:v=$.bG().dV("/api/public/events/theme-design/extract-objects",A.N(["imagesBase64",d,"confidenceThreshold",0.25,"maxDetections",20],y.g,y.b)).cA(B.h5)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a4M,w)},
a2Z(d){return this.beH(d)},
beH(d){var x=0,w=A.l(y.i),v
var $async$a2Z=A.m(function(e,f){if(e===1)return A.i(f,w)
for(;;)switch(x){case 0:v=$.bG().dV("/api/public/events/theme-design/analyze-base",A.N(["baseImageBase64",d],y.g,y.b)).cA(B.h5)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a2Z,w)},
a39(d,e){return this.bf2(d,e)},
bf2(d,e){var x=0,w=A.l(y.i),v
var $async$a39=A.m(function(f,g){if(f===1)return A.i(g,w)
for(;;)switch(x){case 0:v=$.bG().dV("/api/public/events/theme-design/auto-place",A.N(["freeSpaces",d,"objects",e],y.g,y.b)).cA(B.h5)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a39,w)},
a7i(d,e){return this.bqP(d,e)},
bqP(d,e){var x=0,w=A.l(y.i),v
var $async$a7i=A.m(function(f,g){if(f===1)return A.i(g,w)
for(;;)switch(x){case 0:v=$.bG().dV("/api/public/events/theme-design/render-composite",A.N(["baseImageBase64",d,"objects",e],y.g,y.b)).cA(B.h5)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a7i,w)}}
var z=a.updateTypes([]);(function inheritance(){var x=a.inherit
x(D.aLN,A.a8)})()
var y={i:A.ak("U<e,@>"),l:A.ak("U<@,@>"),g:A.ak("e"),b:A.ak("@")};(function constants(){B.h5=new A.bF(18e7)
B.Je=new A.aj(C.IW,null,null,null,null)
B.zc=new A.aj(C.nT,null,null,null,null)
B.IC=new A.al(58460,"MaterialIcons",!0)
B.C7=new A.X(1/0,48)
B.CO=new A.M(!0,C.cT,null,null,null,null,20,C.a5,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
B.CS=new A.M(!0,null,null,null,null,null,12,C.ay,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
B.a36=new A.o("Back",null,null,null,null,null,null,null,null,null,null)})();(function lazyInitializers(){var x=a.lazyFinal
x($,"cKy","tl",()=>new D.aLN())})()};
(a=>{a["OG2mdQf1Icou3h4aV4mzX5V0gWY="]=a.current})($__dart_deferred_initializers__);