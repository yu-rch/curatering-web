((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,D={aLM:function aLM(){}},B,E
J=c[1]
A=c[0]
C=c[2]
D=a.updateHolder(c[14],D)
B=c[32]
E=c[33]
D.aLM.prototype={
EL(d){return this.azG(d)},
azG(d){var x=0,w=A.l(y.i),v,u,t,s,r,q
var $async$EL=A.m(function(e,f){if(e===1)return A.i(f,w)
for(;;)switch(x){case 0:x=3
return A.d(A.et(A.bx("https://curatering.up.railway.app/api/online-inquiries",0,null),C.a6.co(d,null),null,E.kG).cz(C.fo),$async$EL)
case 3:q=f
if(q.b<200||q.b>=300){u="Failed to submit online inquiry ("+q.b+")"
try{s=q
t=C.a6.bq(A.cj(A.ci(s.e)).b7(s.w),null)
if(y.l.b(t)&&t.h(0,"message")!=null)u=J.u(t.h(0,"message"))}catch(p){}throw A.p(A.lh(u,q.b))}s=q
if(C.e.l(A.cj(A.ci(s.e)).b7(s.w)).length===0){v=C.hU
x=1
break}s=q
t=C.a6.bq(A.cj(A.ci(s.e)).b7(s.w),null)
v=y.l.b(t)?A.ax(t,y.g,y.b):C.hU
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$EL,w)},
a5s(d,e,f){return this.blG(d,e,f)},
blG(d,e,f){var x=0,w=A.l(y.i),v
var $async$a5s=A.m(function(g,h){if(g===1)return A.i(h,w)
for(;;)switch(x){case 0:v=$.bG().dV("/api/public/events/theme-design/yolo-sam-infer",A.N(["imageBase64",d,"confidenceThreshold",0.25,"maxDetections",f,"maskFormat",e],y.g,y.b)).cz(B.h6)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a5s,w)},
MB(d,e,f){return this.aEY(d,e,f)},
aEY(d,e,f){var x=0,w=A.l(y.i),v
var $async$MB=A.m(function(g,h){if(g===1)return A.i(h,w)
for(;;)switch(x){case 0:v=$.bG().dV("/api/public/events/theme-design/swap-colors",A.N(["imageBase64",e,"masks",f,"edits",d],y.g,y.b)).cz(B.h6)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$MB,w)},
WO(d,e,f,g,h,i,j,k){return this.ayp(d,e,f,g,h,i,j,k)},
ayp(d,e,f,g,h,i,j,k){var x=0,w=A.l(y.i),v
var $async$WO=A.m(function(l,m){if(l===1)return A.i(m,w)
for(;;)switch(x){case 0:v=$.bG().dV("/api/public/events/theme-design/theme-search",A.N(["eventTitle",e,"eventType",f,"formalityLevel",g,"prompt",j,"baseImageUrl",d,"tags",k,"page",h,"perPage",i],y.g,y.b)).cz(B.h6)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$WO,w)},
a4K(d){return this.bjr(d)},
bjr(d){var x=0,w=A.l(y.i),v
var $async$a4K=A.m(function(e,f){if(e===1)return A.i(f,w)
for(;;)switch(x){case 0:v=$.bG().dV("/api/public/events/theme-design/extract-objects",A.N(["imagesBase64",d,"confidenceThreshold",0.25,"maxDetections",20],y.g,y.b)).cz(B.h6)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a4K,w)},
a2X(d){return this.bes(d)},
bes(d){var x=0,w=A.l(y.i),v
var $async$a2X=A.m(function(e,f){if(e===1)return A.i(f,w)
for(;;)switch(x){case 0:v=$.bG().dV("/api/public/events/theme-design/analyze-base",A.N(["baseImageBase64",d],y.g,y.b)).cz(B.h6)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a2X,w)},
a37(d,e){return this.beO(d,e)},
beO(d,e){var x=0,w=A.l(y.i),v
var $async$a37=A.m(function(f,g){if(f===1)return A.i(g,w)
for(;;)switch(x){case 0:v=$.bG().dV("/api/public/events/theme-design/auto-place",A.N(["freeSpaces",d,"objects",e],y.g,y.b)).cz(B.h6)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a37,w)},
a7g(d,e){return this.bqB(d,e)},
bqB(d,e){var x=0,w=A.l(y.i),v
var $async$a7g=A.m(function(f,g){if(f===1)return A.i(g,w)
for(;;)switch(x){case 0:v=$.bG().dV("/api/public/events/theme-design/render-composite",A.N(["baseImageBase64",d,"objects",e],y.g,y.b)).cz(B.h6)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a7g,w)}}
var z=a.updateTypes([]);(function inheritance(){var x=a.inherit
x(D.aLM,A.a8)})()
var y={i:A.ak("U<e,@>"),l:A.ak("U<@,@>"),g:A.ak("e"),b:A.ak("@")};(function constants(){B.h6=new A.bE(18e7)
B.J6=new A.aj(C.IN,null,null,null,null)
B.z8=new A.aj(C.nT,null,null,null,null)
B.It=new A.al(58460,"MaterialIcons",!0)
B.C4=new A.X(1/0,48)
B.CL=new A.M(!0,C.cT,null,null,null,null,20,C.a5,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
B.CP=new A.M(!0,null,null,null,null,null,12,C.ay,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
B.a2X=new A.o("Back",null,null,null,null,null,null,null,null,null,null)})();(function lazyInitializers(){var x=a.lazyFinal
x($,"cKa","tl",()=>new D.aLM())})()};
(a=>{a["4WbE+KQTA9fuRGfEhLPU+kvNeks="]=a.current})($__dart_deferred_initializers__);