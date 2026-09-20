((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,D={aLN:function aLN(){}},B,E
J=c[1]
A=c[0]
C=c[2]
D=a.updateHolder(c[14],D)
B=c[32]
E=c[33]
D.aLN.prototype={
EL(d){return this.azL(d)},
azL(d){var x=0,w=A.l(y.i),v,u,t,s,r,q
var $async$EL=A.m(function(e,f){if(e===1)return A.i(f,w)
for(;;)switch(x){case 0:x=3
return A.d(A.et(A.bx("https://curatering.up.railway.app/api/online-inquiries",0,null),C.a6.cp(d,null),null,E.kJ).cA(C.fo),$async$EL)
case 3:q=f
if(q.b<200||q.b>=300){u="Failed to submit online inquiry ("+q.b+")"
try{s=q
t=C.a6.bq(A.cj(A.ci(s.e)).b7(s.w),null)
if(y.l.b(t)&&t.h(0,"message")!=null)u=J.u(t.h(0,"message"))}catch(p){}throw A.p(A.li(u,q.b))}s=q
if(C.e.l(A.cj(A.ci(s.e)).b7(s.w)).length===0){v=C.hV
x=1
break}s=q
t=C.a6.bq(A.cj(A.ci(s.e)).b7(s.w),null)
v=y.l.b(t)?A.ax(t,y.g,y.b):C.hV
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$EL,w)},
a5u(d,e,f){return this.blR(d,e,f)},
blR(d,e,f){var x=0,w=A.l(y.i),v
var $async$a5u=A.m(function(g,h){if(g===1)return A.i(h,w)
for(;;)switch(x){case 0:v=$.bG().dV("/api/public/events/theme-design/yolo-sam-infer",A.N(["imageBase64",d,"confidenceThreshold",0.25,"maxDetections",f,"maskFormat",e],y.g,y.b)).cA(B.h6)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a5u,w)},
MB(d,e,f){return this.aF3(d,e,f)},
aF3(d,e,f){var x=0,w=A.l(y.i),v
var $async$MB=A.m(function(g,h){if(g===1)return A.i(h,w)
for(;;)switch(x){case 0:v=$.bG().dV("/api/public/events/theme-design/swap-colors",A.N(["imageBase64",e,"masks",f,"edits",d],y.g,y.b)).cA(B.h6)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$MB,w)},
WR(d,e,f,g,h,i,j,k){return this.ayu(d,e,f,g,h,i,j,k)},
ayu(d,e,f,g,h,i,j,k){var x=0,w=A.l(y.i),v
var $async$WR=A.m(function(l,m){if(l===1)return A.i(m,w)
for(;;)switch(x){case 0:v=$.bG().dV("/api/public/events/theme-design/theme-search",A.N(["eventTitle",e,"eventType",f,"formalityLevel",g,"prompt",j,"baseImageUrl",d,"tags",k,"page",h,"perPage",i],y.g,y.b)).cA(B.h6)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$WR,w)},
a4M(d){return this.bjC(d)},
bjC(d){var x=0,w=A.l(y.i),v
var $async$a4M=A.m(function(e,f){if(e===1)return A.i(f,w)
for(;;)switch(x){case 0:v=$.bG().dV("/api/public/events/theme-design/extract-objects",A.N(["imagesBase64",d,"confidenceThreshold",0.25,"maxDetections",20],y.g,y.b)).cA(B.h6)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a4M,w)},
a2Z(d){return this.beE(d)},
beE(d){var x=0,w=A.l(y.i),v
var $async$a2Z=A.m(function(e,f){if(e===1)return A.i(f,w)
for(;;)switch(x){case 0:v=$.bG().dV("/api/public/events/theme-design/analyze-base",A.N(["baseImageBase64",d],y.g,y.b)).cA(B.h6)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a2Z,w)},
a39(d,e){return this.bf_(d,e)},
bf_(d,e){var x=0,w=A.l(y.i),v
var $async$a39=A.m(function(f,g){if(f===1)return A.i(g,w)
for(;;)switch(x){case 0:v=$.bG().dV("/api/public/events/theme-design/auto-place",A.N(["freeSpaces",d,"objects",e],y.g,y.b)).cA(B.h6)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a39,w)},
a7i(d,e){return this.bqM(d,e)},
bqM(d,e){var x=0,w=A.l(y.i),v
var $async$a7i=A.m(function(f,g){if(f===1)return A.i(g,w)
for(;;)switch(x){case 0:v=$.bG().dV("/api/public/events/theme-design/render-composite",A.N(["baseImageBase64",d,"objects",e],y.g,y.b)).cA(B.h6)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a7i,w)}}
var z=a.updateTypes([]);(function inheritance(){var x=a.inherit
x(D.aLN,A.a8)})()
var y={i:A.ak("V<e,@>"),l:A.ak("V<@,@>"),g:A.ak("e"),b:A.ak("@")};(function constants(){B.h6=new A.bE(18e7)
B.J6=new A.aj(C.IO,null,null,null,null)
B.zc=new A.aj(C.nT,null,null,null,null)
B.Iu=new A.al(58460,"MaterialIcons",!0)
B.C7=new A.X(1/0,48)
B.CO=new A.M(!0,C.cS,null,null,null,null,20,C.a5,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
B.CS=new A.M(!0,null,null,null,null,null,12,C.ay,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
B.a2Z=new A.o("Back",null,null,null,null,null,null,null,null,null,null)})();(function lazyInitializers(){var x=a.lazyFinal
x($,"cKq","tl",()=>new D.aLN())})()};
(a=>{a["uYbyDjMDE0/0R2zTYHReg839U/A="]=a.current})($__dart_deferred_initializers__);